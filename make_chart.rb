require 'zlib'
TOP_MODE = ARGV[0] == 'top'
SALARY_MODE = ARGV[0] == 'salary'
W, H = (TOP_MODE || SALARY_MODE) ? [1400, 900] : [1280, 820]
BG = [248, 250, 252]
PIX = Array.new(H) { Array.new(W) { BG.dup } }
def rect(x,y,w,h,c)
  x0=[x.to_i,0].max; y0=[y.to_i,0].max; x1=[(x+w).to_i,W].min; y1=[(y+h).to_i,H].min
  (y0...y1).each { |yy| (x0...x1).each { |xx| PIX[yy][xx]=c } }
end
def line(x1,y1,x2,y2,c)
  if x1==x2
    rect(x1,[y1,y2].min,1,(y2-y1).abs+1,c)
  else
    rect([x1,x2].min,y1,(x2-x1).abs+1,1,c)
  end
end
FONT={
'A'=>['01110','10001','10001','11111','10001','10001','10001'],'B'=>['11110','10001','10001','11110','10001','10001','11110'],'C'=>['01111','10000','10000','10000','10000','10000','01111'],'D'=>['11110','10001','10001','10001','10001','10001','11110'],'E'=>['11111','10000','10000','11110','10000','10000','11111'],'F'=>['11111','10000','10000','11110','10000','10000','10000'],'G'=>['01111','10000','10000','10111','10001','10001','01111'],'H'=>['10001','10001','10001','11111','10001','10001','10001'],'I'=>['11111','00100','00100','00100','00100','00100','11111'],'J'=>['00111','00010','00010','00010','10010','10010','01100'],'K'=>['10001','10010','10100','11000','10100','10010','10001'],'L'=>['10000','10000','10000','10000','10000','10000','11111'],'M'=>['10001','11011','10101','10101','10001','10001','10001'],'N'=>['10001','11001','10101','10011','10001','10001','10001'],'O'=>['01110','10001','10001','10001','10001','10001','01110'],'P'=>['11110','10001','10001','11110','10000','10000','10000'],'Q'=>['01110','10001','10001','10001','10101','10010','01101'],'R'=>['11110','10001','10001','11110','10100','10010','10001'],'S'=>['01111','10000','10000','01110','00001','00001','11110'],'T'=>['11111','00100','00100','00100','00100','00100','00100'],'U'=>['10001','10001','10001','10001','10001','10001','01110'],'V'=>['10001','10001','10001','10001','10001','01010','00100'],'W'=>['10001','10001','10001','10101','10101','10101','01010'],'X'=>['10001','10001','01010','00100','01010','10001','10001'],'Y'=>['10001','10001','01010','00100','00100','00100','00100'],'Z'=>['11111','00001','00010','00100','01000','10000','11111'],
'0'=>['01110','10001','10011','10101','11001','10001','01110'],'1'=>['00100','01100','00100','00100','00100','00100','01110'],'2'=>['01110','10001','00001','00010','00100','01000','11111'],'3'=>['11110','00001','00001','01110','00001','00001','11110'],'4'=>['00010','00110','01010','10010','11111','00010','00010'],'5'=>['11111','10000','10000','11110','00001','00001','11110'],'6'=>['01110','10000','10000','11110','10001','10001','01110'],'7'=>['11111','00001','00010','00100','01000','01000','01000'],'8'=>['01110','10001','10001','01110','10001','10001','01110'],'9'=>['01110','10001','10001','01111','00001','00001','01110'],
' '=>['00000','00000','00000','00000','00000','00000','00000'],'.'=>['00000','00000','00000','00000','00000','00110','00110'],','=>['00000','00000','00000','00000','00110','00110','00100'],':'=>['00000','00110','00110','00000','00110','00110','00000'],'-'=>['00000','00000','00000','11111','00000','00000','00000'],'%'=>['11001','11010','00100','01000','10110','00110','00000'],'/'=>['00001','00010','00010','00100','01000','01000','10000'],'·'=>['00000','00000','00100','01110','00100','00000','00000'],'('=>['00010','00100','01000','01000','01000','00100','00010'],')'=>['01000','00100','00010','00010','00010','00100','01000']
}
def draw_text(x,y,text,scale,color)
  t=text.upcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/,'')
  cx=x
  t.each_char do |ch|
    glyph=FONT[ch] || FONT[' ']
    glyph.each_with_index do |row,ry|
      row.chars.each_with_index do |bit,rx|
        rect(cx+rx*scale,y+ry*scale,scale,scale,color) if bit=='1'
      end
    end
    cx += 6*scale
  end
end
WHITE=[255,255,255]; NAVY=[23,43,77]; TEXT=[43,59,79]; MUTED=[99,116,136]; GRID=[221,228,236]; BARBG=[225,233,242]; BLUE=[39,102,168]
# Chart content
if SALARY_MODE
  require 'json'
  data=JSON.parse(File.read('resume.json'))
  offers=data['offres'].select{|o|o['smin'] || o['smax']}
  values=offers.map{|o|((o['smin']||o['smax'])+(o['smax']||o['smin']))/2.0}
  sorted=values.sort
  median=sorted.length.odd? ? sorted[sorted.length/2] : (sorted[sorted.length/2-1]+sorted[sorted.length/2])/2.0
  mean=values.sum/values.length
  euro=lambda{|n|n.round.to_s.reverse.scan(/.{1,3}/).join(' ').reverse}
  draw_text(70,44,'SALAIRES INDIQUES DANS LES OFFRES',4,NAVY)
  draw_text(72,101,"#{offers.length} SALAIRES SUR #{data['offres'].length} OFFRES  |  BRUT ANNUEL ESTIME",2,MUTED)
  draw_text(72,151,"MOYENNE  #{euro.call(mean)} EUR",3,NAVY)
  draw_text(530,151,"MEDIANE  #{euro.call(median)} EUR",3,NAVY)
  x0=170; xw=1092; ytop=266; ybottom=690; ymax=350
  [0,100,200,300].each do |tick|
    y=ybottom-(tick.fdiv(ymax)* (ybottom-ytop)).round
    line(x0,y,x0+xw,y,GRID)
    draw_text(120,y-7,tick.to_s,2,MUTED)
  end
  (0..13).each do |i|
    x=x0+i*(xw/13.0)
    line(x.round,ytop,x.round,ybottom,GRID)
    draw_text(x.round-16,710,"#{i*10}k",2,MUTED)
  end
  bins=Array.new(13,0)
  values.each{|v|idx=[(v/10000).floor,12].min;bins[idx]+=1}
  binw=xw/13.0
  bins.each_with_index do |count,i|
    bh=(count.fdiv(ymax)*(ybottom-ytop)).round
    rect(x0+i*binw+5,ybottom-bh,binw-10,bh,BLUE)
  end
  median_x=x0+(median/130000.0*xw).round
  mean_x=x0+(mean/130000.0*xw).round
  line(median_x,ytop,median_x,ybottom,[128,91,166])
  line(mean_x,ytop,mean_x,ybottom,[221,116,54])
  draw_text(72,770,'MEDIANE',2,[128,91,166]); draw_text(210,770,'MOYENNE',2,[221,116,54])
  draw_text(72,820,'LES FOURCHETTES SONT REPRESENTEES PAR LEUR POINT MILIEU',2,MUTED)
  puts "n=#{values.length} total=#{data['offres'].length} mean=#{mean.round(2)} median=#{median.round(2)}"
  offers.group_by{|o|o['contrat']}.each do |k,v|
    a=v.map{|o|((o['smin']||o['smax'])+(o['smax']||o['smin']))/2.0}.sort
    m=a.length.odd? ? a[a.length/2] : (a[a.length/2-1]+a[a.length/2])/2.0
    puts "contract\t#{k}\t#{a.length}\tmean=#{(a.sum/a.length).round}\tmedian=#{m.round}"
  end
  refs=data['metiers'].to_h{|m|[m['code'],m['libelle']]}
  offers.group_by{|o|o['rome']}.map do |k,v|
    a=v.map{|o|((o['smin']||o['smax'])+(o['smax']||o['smin']))/2.0}.sort
    m=a.length.odd? ? a[a.length/2] : (a[a.length/2-1]+a[a.length/2])/2.0
    [k,v.length,m.round,refs[k]]
  end.select{|r|r[1]>=10}.sort_by{|r|r[2]}.each{|r|puts "rome\t#{r[0]}\t#{r[3]}\t#{r[1]}\tmedian=#{r[2]}"}
elsif TOP_MODE
  draw_text(70,44,'LES 10 INTITULES DE POSTES LES PLUS FREQUENTS',4,NAVY)
  draw_text(72,101,'FRANCE  |  3 280 OFFRES ACTIVES  |  DONNEES AU 28 SEPTEMBRE 2026',2,MUTED)
  draw_text(72,151,'INTITULE DU POSTE',2,MUTED)
  draw_text(660,151,"NOMBRE D'OFFRES",2,MUTED)
  chart_x=660; chart_w=600; chart_top=178; chart_bottom=795
  [0,50,100,150,200].each_with_index do |tick,i|
    x=chart_x+i*150
    line(x,chart_top,x,chart_bottom,GRID)
    draw_text(x-8,812,tick.to_s,2,MUTED)
  end
  rows=[
    ['DIRECTEUR / DIRECTRICE COMMUNICATION ET MARKETING DIGITAL (H/F)',190],
    ['CONSEILLER DE VENTE (H/F)',86],
    ['AGENT COMMERCIAL INDEPENDANT (H/F)',41],
    ['ASSISTANT / ASSISTANTE MARKETING (H/F)',33],
    ['CHARGE / CHARGEE DE COMMUNICATION DIGITALE (H/F)',31],
    ['COMMUNITY MANAGER (H/F)',20],
    ['CHARGE / CHARGEE DE MISSION EVENEMENTIEL (H/F)',20],
    ['CHARGE / CHARGEE MARKETING DIGITAL (H/F)',18],
    ['CHARGE DE CLIENTELE (H/F)',17],
    ['CHARGE DE RELATION CLIENT (H/F)',16]
  ]
  rows.each_with_index do |(label,count),i|
    y=184+i*61
    words=label.split(' '); lines=['']; words.each do |word|
      if (lines[-1].length+word.length+1)*12 > 550
        lines << word
      else
        lines[-1] += (lines[-1].empty? ? '' : ' ')+word
      end
    end
    lines.each_with_index { |part,j| draw_text(72,y+5+j*16,part,2,TEXT) }
    rect(chart_x,y+8,chart_w,28,BARBG)
    rect(chart_x,y+8,(count*3).round,28,BLUE)
    draw_text(1280,y+15,count.to_s,2,TEXT)
  end
  draw_text(72,865,'SOURCE : RESUME.JSON  |  INTITULES REGROUPES SANS DISTINGUER LES MAJUSCULES',2,MUTED)
else
  draw_text(70,48,'REPARTITION DES OFFRES PAR TYPE DE CONTRAT',4,NAVY)
  draw_text(72,105,'FRANCE  |  3 280 OFFRES ACTIVES  |  DONNEES AU 28 SEPTEMBRE 2026',2,MUTED)
  draw_text(72,156,'TYPE DE CONTRAT',2,MUTED)
  draw_text(500,156,'PART DES OFFRES',2,MUTED)
  chart_x=500; chart_w=540; chart_top=185; chart_bottom=675
  (0..6).each do |i|
    x=chart_x+i*90
    line(x,chart_top,x,chart_bottom,GRID)
    draw_text(x-10,692,"#{i*10}%",2,MUTED)
  end
  rows=[
   ['CDI',1672,50.98],['CDD',987,30.09],['INTERIM',275,8.38],['FRANCHISE',193,5.88],['PROFESSION LIBERALE',97,2.96],['PROFESSION COMMERCIALE',48,1.46],['SAISONNIER',6,0.18],['CDI DE CHANTIER',2,0.06]
  ]
  rows.each_with_index do |(label,count,pct),i|
    y=194+i*60
    draw_text(72,y+7,label,2,TEXT)
    rect(chart_x,y,chart_w,32,BARBG)
    bw=[(pct*9).round,1].max
    rect(chart_x,y,bw,32,BLUE)
    value=("%.2f"%pct).tr('.',',')
    draw_text(1060,y+8,"#{value}%  ·  #{count}",2,TEXT)
  end
  draw_text(72,770,'SOURCE : RESUME.JSON  |  CALCUL SUR 3 280 OFFRES',2,MUTED)
end
# Encode truecolor PNG
raw=PIX.map { |row| "\x00".b + row.flatten.pack('C*') }.join
chunk=lambda do |type,data|
  type=type.b; data=data.b
  [data.bytesize].pack('N')+type+data+[Zlib.crc32(type+data)].pack('N')
end
png="\x89PNG\r\n\x1a\n".b
png << chunk.call('IHDR',[W,H,8,2,0,0,0].pack('NNC5'))
png << chunk.call('IDAT',Zlib::Deflate.deflate(raw,9))
png << chunk.call('IEND',''.b)
output=SALARY_MODE ? '3_distribution_salaires.png' : (TOP_MODE ? '2_top_metiers.png' : '1_types_contrats.png')
File.binwrite(output,png)
