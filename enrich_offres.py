#!/usr/bin/env python3
"""Enrichit les offres nommées de resume.json via Recherche d'entreprises.

La source resume.json est alimentée par le collecteur France Travail du projet.
L'API Recherche d'entreprises est interrogée par dénomination (l'API ne fournit
pas de recherche exhaustive d'entreprises par commune). Les rapprochements sont
marqués exacts uniquement si le nom ou une enseigne correspond et si
l'établissement est dans le département de l'offre. Aucun rapprochement n'est
fait sans nom. Toutes les offres restent présentes dans le fichier de sortie.
"""

from __future__ import annotations

import json
import argparse
import re
import sys
import time
import unicodedata
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


BASE = Path(__file__).resolve().parent
SOURCE = BASE / "resume.json"
OUTPUT = BASE / "offres_enrichies.json"
JS_OUTPUT = BASE / "enriched-data.js"
API = "https://recherche-entreprises.api.gouv.fr/search"
USER_AGENT = "data-IAE-CM2/1.0 (enrichissement pedagogique)"

EFFECTIFS = {
    "00": "0 salarié",
    "01": "1–2 salariés",
    "02": "3–5 salariés",
    "03": "6–9 salariés",
    "11": "10–19 salariés",
    "12": "20–49 salariés",
    "21": "50–99 salariés",
    "22": "100–199 salariés",
    "31": "200–249 salariés",
    "32": "250–499 salariés",
    "41": "500–999 salariés",
    "42": "1 000–1 999 salariés",
    "51": "2 000–4 999 salariés",
    "52": "5 000–9 999 salariés",
    "53": "10 000 salariés ou plus",
    "NN": "Non renseigné",
}


def normalize(value: object) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(char for char in text if not unicodedata.combining(char))
    return re.sub(r"[^A-Z0-9]+", " ", text.upper()).strip()


def commune_from_location(location: object) -> str:
    text = re.sub(r"^\s*63\s*[-–]\s*", "", str(location or ""))
    return normalize(text)


def department_for_offer(offer: dict) -> str:
    department = str(offer.get("dep") or "")
    # France Travail may collapse all overseas departments into "97"; recover
    # the actual one from the postal prefix retained in the location label.
    if department == "97":
        match = re.match(r"^\s*(97[1-8])\s*[-–]", str(offer.get("lieu") or ""))
        if match:
            return match.group(1)
    return department


_request_lock = threading.Lock()
_last_request = 0.0


def fetch_company(query: str) -> list[dict]:
    params = urlencode({"q": query, "per_page": 25})
    request = Request(
        f"{API}?{params}",
        headers={"Accept": "application/json", "User-Agent": USER_AGENT},
    )
    for attempt in range(4):
        try:
            global _last_request
            with _request_lock:
                wait = 0.18 - (time.monotonic() - _last_request)
                if wait > 0:
                    time.sleep(wait)
                _last_request = time.monotonic()
            with urlopen(request, timeout=30) as response:
                data = json.load(response)
            return data.get("results", [])
        except HTTPError as error:
            if error.code == 429 and attempt < 3:
                time.sleep(int(error.headers.get("Retry-After", "2")))
                continue
            raise RuntimeError(f"API Recherche d'entreprises ({error.code}) pour {query!r}") from error
        except (URLError, TimeoutError) as error:
            if attempt < 3:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"Erreur réseau pour {query!r}: {error}") from error
    return []


def company_names(result: dict) -> set[str]:
    names = {
        normalize(result.get("nom_complet")),
        normalize(result.get("nom_raison_sociale")),
        normalize(result.get("sigle")),
    }
    for establishment in result.get("matching_etablissements") or []:
        names.add(normalize(establishment.get("nom_commercial")))
        names.update(normalize(name) for name in establishment.get("liste_enseignes") or [])
    seat = result.get("siege") or {}
    names.add(normalize(seat.get("nom_commercial")))
    names.update(normalize(name) for name in seat.get("liste_enseignes") or [])
    return {name for name in names if name}


def local_establishments(result: dict, department: str) -> list[dict]:
    items = [result.get("siege") or {}]
    items.extend(result.get("matching_etablissements") or [])
    unique = {}
    for item in items:
        postal_prefix = "2A" if department == "2A" else "2B" if department == "2B" else department if len(department) > 2 else department[:2]
        if str(item.get("departement", "")) == department or str(item.get("code_postal", "")).startswith(postal_prefix):
            key = item.get("siret") or (item.get("commune"), item.get("adresse"))
            unique[key] = item
    return list(unique.values())


def choose_match(name: str, location: str, department: str, results: list[dict]) -> tuple[dict | None, str]:
    target = normalize(name)
    target_city = commune_from_location(location)
    candidates = []
    for result in results:
        establishments = local_establishments(result, department)
        if not establishments:
            continue
        names = company_names(result)
        if target not in names:
            continue
        city_matches = [
            item for item in establishments
            if normalize(item.get("libelle_commune")) == target_city
        ]
        chosen_establishment = (city_matches or establishments)[0]
        score = 2 if city_matches else 1
        candidates.append((score, result, chosen_establishment))
    if not candidates:
        return None, "aucune_correspondance_exacte_dans_le_63"
    candidates.sort(key=lambda item: (item[0], item[1].get("etat_administratif") == "A"), reverse=True)
    best = candidates[0]
    if len(candidates) > 1 and candidates[1][0] == best[0]:
        return None, "correspondance_ambigue"
    return {"unite_legale": best[1], "etablissement": best[2]}, (
        "nom_exact_commune_exacte" if best[0] == 2 else "nom_exact_etablissement_dans_le_63"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=0, help="limiter les noms à enrichir (0 = toute la base)")
    args = parser.parse_args()
    if not SOURCE.exists():
        print(f"Fichier source absent : {SOURCE}", file=sys.stderr)
        return 2

    source_data = json.loads(SOURCE.read_text(encoding="utf-8"))
    offers = source_data.get("offres", [])
    names = sorted({str(offer["entreprise"]).strip() for offer in offers if offer.get("entreprise")})
    if args.limit > 0:
        names = names[:args.limit]
    print(f"{len(offers)} offres dans la base ; {len(names)} dénominations à rechercher.", flush=True)

    results_by_name = {}
    errors = {}
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = {pool.submit(fetch_company, name): name for name in names}
        for index, future in enumerate(as_completed(futures), start=1):
            name = futures[future]
            try:
                results_by_name[name] = future.result()
            except Exception as error:
                results_by_name[name] = []
                errors[name] = str(error)
            if index % 50 == 0 or index == len(names):
                print(f"API : {index}/{len(names)} entreprises traitées", flush=True)

    enriched = []
    for offer in offers:
        name = str(offer.get("entreprise") or "").strip()
        if not name:
            match, status = None, "nom_entreprise_absent_de_l_offre"
        else:
            department = department_for_offer(offer)
            if not department:
                match, status = None, "departement_offre_absent"
            elif name in errors:
                match, status = None, "erreur_api"
            else:
                match, status = choose_match(name, str(offer.get("lieu") or ""), department, results_by_name.get(name, []))

        legal = (match or {}).get("unite_legale") or {}
        establishment = (match or {}).get("etablissement") or {}
        effectif = establishment.get("tranche_effectif_salarie") or legal.get("tranche_effectif_salarie")
        enriched.append({
            **offer,
            "enrichissement_entreprise": {
                "statut_rapprochement": status,
                "siren": legal.get("siren") if match else None,
                "siret_etablissement": establishment.get("siret") if match else None,
                "commune_insee": establishment.get("commune") if match else None,
                "commune_entreprise": establishment.get("libelle_commune") if match else None,
                "taille_entreprise": legal.get("categorie_entreprise") if match else None,
                "tranche_effectif_code": effectif if match else None,
                "tranche_effectif": EFFECTIFS.get(str(effectif), "Non renseigné") if match else None,
                "code_naf": legal.get("activite_principale") if match else None,
                "section_activite": legal.get("section_activite_principale") if match else None,
                "activite_source_offre": offer.get("secteur"),
                "source_api": API if match else None,
            },
        })

    counts = {}
    for offer in enriched:
        status = offer["enrichissement_entreprise"]["statut_rapprochement"]
        counts[status] = counts.get(status, 0) + 1

    payload = {
        "date_enrichissement": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source_offres": {
            "fichier": SOURCE.name,
            "date_donnees": source_data.get("date"),
            "source": source_data.get("source"),
        },
        "source_enrichissement": API,
        "nombre_noms_recherches": len(names),
        "nombre_erreurs_api": len(errors),
        "erreurs_api": errors,
        "nombre_offres": len(enriched),
        "bilan_rapprochements": counts,
        "offres": enriched,
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    compact = {
        str(offer.get("id")): offer["enrichissement_entreprise"]
        for offer in enriched if offer.get("id")
    }
    js_meta = {"date_enrichissement": payload["date_enrichissement"], "nombre_offres": len(enriched), "bilan_rapprochements": counts}
    JS_OUTPUT.write_text("window.COMPANY_ENRICHMENT_META = " + json.dumps(js_meta, ensure_ascii=False, separators=(",", ":")) + ";\nwindow.COMPANY_ENRICHMENTS = " + json.dumps(compact, ensure_ascii=False, separators=(",", ":")) + ";\n", encoding="utf-8")
    print(f"Fichiers créés : {OUTPUT.name}, {JS_OUTPUT.name}")
    print("Bilan : " + json.dumps(counts, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
