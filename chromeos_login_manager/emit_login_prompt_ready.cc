// Copyright (c) 2009 The Chromium OS Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <stdlib.h>
#include <unistd.h>

int main() {
  setresuid(0,0,0);
  return system("/sbin/initctl emit login-prompt-ready &");
}
