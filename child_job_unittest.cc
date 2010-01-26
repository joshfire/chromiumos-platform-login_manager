// Copyright (c) 2009-2010 The Chromium OS Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "login_manager/child_job.h"

#include <gtest/gtest.h>
#include <unistd.h>

#include <base/command_line.h>
#include <base/logging.h>

namespace login_manager {

class SetUidExecJobTest : public ::testing::Test { };

TEST(SetUidExecJobTest, PopulateArgvTest) {
  const char *my_argv[] = { "zero",
                            "one",
                            "two" };
  const int my_argc = 3;
  CommandLine cl(my_argc, my_argv);

  SetUidExecJob job(&cl, NULL, false);

  std::vector<std::string> data = job.ExtractArgvForTest();
  std::vector<std::string>::const_iterator it  = data.begin();
  for (int i = 1; i < my_argc; ++i) {
    EXPECT_EQ(my_argv[i], *it);
    ++it;
  }
  EXPECT_TRUE(data.end() == it);
}

// I would love to re-use the code in the following functions, but I'd
// have to make several methods of SetUidExecJob public to do so.
TEST(SetUidExecJobTest, FlagAppendTest) {
  const char *my_argv[] = { "zero",
                            "one",
                            "two" };
  const int my_argc = 3;
  CommandLine cl(my_argc, my_argv);

  SetUidExecJob job(&cl, NULL, true);
  job.UseLoginManagerFlagIfNeeded();

  std::vector<std::string> data = job.ExtractArgvForTest();
  std::vector<std::string>::const_iterator it  = data.begin();
  for (int i = 1; i < my_argc; ++i) {
    EXPECT_EQ(my_argv[i], *it);
    ++it;
  }
  EXPECT_EQ(SetUidExecJob::kLoginManagerFlag, *it++);
  EXPECT_TRUE(data.end() == it) << *it;
}

TEST(SetUidExecJobTest, NoFlagAppendTest) {
  const char *my_argv[] = { "zero",
                            "one",
                            "two" };
  const int my_argc = 3;
  CommandLine cl(my_argc, my_argv);

  SetUidExecJob job(&cl, NULL, true);
  job.Toggle();
  job.UseLoginManagerFlagIfNeeded();  // should be a no-op

  std::vector<std::string> data = job.ExtractArgvForTest();
  std::vector<std::string>::const_iterator it  = data.begin();
  for (int i = 1; i < my_argc; ++i) {
    EXPECT_EQ(my_argv[i], *it);
    ++it;
  }
  EXPECT_TRUE(data.end() == it) << *it;
}

}  // namespace login_manager