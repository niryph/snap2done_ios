// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif

// Fix for non-modular import
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonmodular-include-in-framework-module"
#import <Firebase/Firebase.h>
#pragma clang diagnostic pop

#import <Foundation/Foundation.h>
#import "CustomPigeonHeader.h"
#import "PigeonParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLTAuthStateChannelStreamHandler : NSObject <FlutterStreamHandler>

- (instancetype)initWithAuth:(FIRAuth *)auth;

@end

NS_ASSUME_NONNULL_END 