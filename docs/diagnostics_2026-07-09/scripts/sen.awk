{ n++; p=$12; r=$13
  if(n==1){t=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$3,$1,$2,$4,$5,$6)}
  sp+=p; sp2+=p*p; sr+=r; sr2+=r*r
  if(n==60){
    mp=sp/60; mr=sr/60
    vp=sp2/60-mp*mp; vr=sr2/60-mr*mr
    if(vp<0)vp=0; if(vr<0)vr=0
    printf "%s,%.3f,%.3f,%.3f,%.3f\n", t, mp, sqrt(vp), mr, sqrt(vr)
    n=0; sp=0; sp2=0; sr=0; sr2=0
  } }
