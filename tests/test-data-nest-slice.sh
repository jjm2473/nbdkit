#!/usr/bin/env bash
# nbdkit
# Copyright (C) 2018-2020 Red Hat Inc.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# * Neither the name of Red Hat nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY RED HAT AND CONTRIBUTORS ''AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL RED HAT OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# Test the data plugin with ( nesting )[N:M].

source ./functions.sh
set -e
set -x

requires nbdsh --version

sock=`mktemp -u`
files="data-nest-slice.pid $sock"
rm -f $files
cleanup_fn rm -f $files

# Run nbdkit.
start_nbdkit -P data-nest-slice.pid -U $sock \
       data '
# Try various slices of a string.
( $hello )[:4]
( "Hello" )[3:]
( "Hello" )[3:5]
# With the new parser it should work without the parens too.
"Hello"[:]
$hello[:]
$hello[:4]
"Hello"[3:]
"Hello"[3:5]
# Zero length slices are optimized out.  The first index is ignored.
"Hello"[:0]
"Hello"[99:99]
' \
       hello=' "Hello" '

nbdsh --connect "nbd+unix://?socket=$sock" \
      -c '
print("%d" % h.get_size())
assert h.get_size() == 4+2+2+5+5+4+2+2
buf = h.pread(h.get_size(), 0)
print("%r" % buf)
assert buf == b"HellloloHelloHelloHelllolo"
'