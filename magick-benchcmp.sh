#!/bin/sh
# Copyright 2011 The Go Authors.  All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

CGO=$(mktemp)
GO=$(mktemp)

grep -v -P 'Go\t' $1 > ${CGO}
grep -P 'Go\t' $1 |sed 's/Go\t//' > ${GO}

awk '
BEGIN {
	n = 0
}

$1 ~ /Benchmark/ && $4 == "ns/op" {
	if(old[$1]) {
		if(!saw[$1]++) {
			name[n++] = $1
			if(length($1) > len)
				len = length($1)
		}
		new[$1] = $3
		if($6 == "MB/s")
			newmb[$1] = $5

		# allocs/op might be at $8 or $10 depending on if
		# SetBytes was used or not.
		# B/op might be at $6 or $8, it should be immediately
		# followed by allocs/op
		if($8 == "allocs/op") {
			newbytes[$1] = $5
			newalloc[$1] = $7
		}
		if($10 == "allocs/op") {
			newbytes[$1] = $7
			newalloc[$1] = $9
		}
	} else {
		old[$1] = $3
		if($6 == "MB/s")
			oldmb[$1] = $5
		if($8 == "allocs/op") {
			oldbytes[$1] = $5
			oldalloc[$1] = $7
		}
		if($10 == "allocs/op") {
			oldbytes[$1] = $7
			oldalloc[$1] = $9
		}
	}
}

END {
	if(n == 0) {
		print "benchcmp: no repeated benchmarks" >"/dev/stderr"
		exit 1
	}

	printf("%-*s %12s %12s  %7s\n", len, "benchmark", "magick ns/op", "go ns/op", "delta")

	# print ns/op
	for(i=0; i<n; i++) {
		what = name[i]
		printf("%-*s %12d %12d  %6s%%\n", len, what, old[what], new[what],
			sprintf("%+.2f", 100*new[what]/old[what]-100))
	}

	# print mb/s
	anymb = 0
	for(i=0; i<n; i++) {
		what = name[i]
		if(!(what in newmb))
			continue
		if(anymb++ == 0)
			printf("\n%-*s %12s %12s  %7s\n", len, "benchmark", "magick MB/s", "go MB/s", "speedup")
		printf("%-*s %12s %12s  %6sx\n", len, what,
			sprintf("%.2f", oldmb[what]),
			sprintf("%.2f", newmb[what]),
			sprintf("%.2f", newmb[what]/oldmb[what]))
	}

	# print allocs
	anyalloc = 0
	for(i=0; i<n; i++) {
		what = name[i]
		if(!(what in newalloc))
			continue
		if(anyalloc++ == 0)
			printf("\n%-*s %12s %12s  %7s\n", len, "benchmark", "magick allocs", "go allocs", "delta")
		if(oldalloc[what] == 0)
			delta="n/a"
		else
			delta=sprintf("%.2f", 100*newalloc[what]/oldalloc[what]-100)
		printf("%-*s %12d %12d  %6s%%\n", len, what,
			oldalloc[what], newalloc[what], delta)
	}

	# print alloc bytes
	anybytes = 0
	for(i=0; i<n; i++) {
		what = name[i]
		if(!(what in newbytes))
			continue
		if(anybytes++ == 0)
			printf("\n%-*s %12s %12s  %7s\n", len, "benchmark", "magick bytes", "go bytes", "delta")
		if(oldbytes[what] == 0)
			delta="n/a"
		else
			delta=sprintf("%.2f", 100*newbytes[what]/oldbytes[what]-100)
		printf("%-*s %12d %12d  %6s%%\n", len, what,
			oldbytes[what], newbytes[what], delta)
	}
}
' ${CGO} ${GO}

rm -f ${CGO} ${GO}
