// Copyright (c) 2012-2016, The CryptoNote developers, The Bytecoin developers
//
// This file is part of DCRS.
//
// DCRS is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// DCRS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with DCRS.  If not, see <http://www.gnu.org/licenses/>.

#include <mutex>
#include <condition_variable>

#pragma once

class EventWaiter {
private:
  std::mutex mtx;
  std::condition_variable cv;
  bool available;

public:
  EventWaiter() : available(false) {}

  void notify();
  void wait();
  bool wait_for(const std::chrono::milliseconds& rel_time);
};
