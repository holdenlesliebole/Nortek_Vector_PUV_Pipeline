{ n++
  c1=$12; c2=$13; c3=$14; p=$15
  mn=c1; if(c2<mn)mn=c2; if(c3<mn)mn=c3
  if(mn<70) badmin++
  if(c1<70) b1++; if(c2<70) b2++; if(c3<70) b3++
  s1+=c1; s2+=c2; s3+=c3; sp+=p; sa+=($6+$7+$8)/3
  if(n==1200){ blk++
    printf "%d,%.4f,%.4f,%.4f,%.4f,%.1f,%.1f,%.1f,%.3f,%.1f\n", blk, badmin/1200, b1/1200, b2/1200, b3/1200, s1/1200, s2/1200, s3/1200, sp/1200, sa/1200
    n=0;badmin=0;b1=0;b2=0;b3=0;s1=0;s2=0;s3=0;sp=0;sa=0
  } }
