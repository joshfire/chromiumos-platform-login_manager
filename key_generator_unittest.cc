// Copyright (c) 2011 The Chromium OS Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "login_manager/key_generator.h"

#include <base/basictypes.h>
#include <base/memory/ref_counted.h>
#include <gtest/gtest.h>
#include <signal.h>
#include <unistd.h>

#include "login_manager/mock_child_job.h"
#include "login_manager/mock_owner_key.h"
#include "login_manager/mock_system_utils.h"
#include "login_manager/session_manager_service.h"

namespace login_manager {
using ::testing::A;
using ::testing::Invoke;
using ::testing::Return;
using ::testing::StrEq;
using ::testing::_;

// compatible with void Run()
static void CleanExit() { _exit(0); }

class KeyGeneratorTest : public ::testing::Test {
 public:
  KeyGeneratorTest() : manager_(NULL) {}

  virtual ~KeyGeneratorTest() {}

  virtual void SetUp() {
    std::vector<ChildJobInterface*> jobs;
    manager_ = new SessionManagerService(jobs);
  }

  virtual void TearDown() {
    manager_ = NULL;
  }

 protected:
  scoped_refptr<SessionManagerService> manager_;
  scoped_ptr<MockSystemUtils> utils_;

 private:
  DISALLOW_COPY_AND_ASSIGN(KeyGeneratorTest);
};

TEST_F(KeyGeneratorTest, GenerateKey) {
  MockChildJob* k_job = new MockChildJob;
  EXPECT_CALL(*k_job, SetDesiredUid(getuid()))
      .Times(1);
  EXPECT_CALL(*k_job, IsDesiredUidSet())
      .WillRepeatedly(Return(true));
  ON_CALL(*k_job, Run())
      .WillByDefault(Invoke(CleanExit));
  int keygen_pid = 8;

  MockOwnerKey key;
  EXPECT_CALL(key, PopulateFromDiskIfPossible())
      .WillRepeatedly(Return(true));
  EXPECT_CALL(key, StartGeneration(k_job))
      .WillOnce(Return(keygen_pid));

  KeyGenerator keygen;
  keygen.InjectMockKeygenJob(k_job);  // Takes ownership.
  EXPECT_TRUE(keygen.Start(getuid(), &key, manager_.get()));
}

}  // namespace login_manager
