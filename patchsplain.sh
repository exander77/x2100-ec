#!/bin/bash
awk 'NR==1{p=0}{n=strtonum($1); print $1, "+", n-p, $2; p=strtonum(n)}END{}' $1
