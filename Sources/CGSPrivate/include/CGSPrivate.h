//
//  CGSPrivate.h
//  SpaceRenamer
//
//  Private macOS APIs for interacting with Spaces.
//  These symbols are resolved at runtime from SkyLight framework.
//

#ifndef CGSPrivate_h
#define CGSPrivate_h

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>

// Connection to Core Graphics Server
typedef int CGSConnectionID;

// Space identifier (numeric)
typedef uint64_t CGSSpaceID;

// Get the main connection to CGS
extern CGSConnectionID CGSMainConnectionID(void);

// Get all managed display spaces
// Returns CFArrayRef of CFDictionaryRef with space information
extern CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);

// Get the currently active space
extern CGSSpaceID CGSGetActiveSpace(CGSConnectionID cid);

// Set the display name for a Space (appears in Mission Control)
extern CGError CGSSpaceSetName(CGSConnectionID cid, CGSSpaceID sid, CFStringRef name);

#endif /* CGSPrivate_h */
