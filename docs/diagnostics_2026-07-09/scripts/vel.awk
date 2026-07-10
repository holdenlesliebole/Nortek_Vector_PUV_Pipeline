NR>=5788797 && NR<=8035197 {
  n++
  u=$3; v=$4; w=$5
  c=$12; if($13<c)c=$13; if($14<c)c=$14
  su+=u; su2+=u*u; sv+=v; sv2+=v*v; sw+=w; sw2+=w*w; sc+=c; sp+=$15
  if(c<70) bad++
  if(n==2400){ blk++
    mu=su/2400; mv=sv/2400; mw=sw/2400
    printf "%d,%.5f,%.5f,%.5f,%.5f,%.5f,%.1f,%.4f,%.3f\n", blk, mu, sqrt(su2/2400-mu*mu), mv, sqrt(sv2/2400-mv*mv), mw, sc/2400, bad/2400, sp/2400
    n=0;su=0;su2=0;sv=0;sv2=0;sw=0;sw2=0;sc=0;sp=0;bad=0
  } }
NR>8035197 {exit}
