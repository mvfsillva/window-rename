//
//  CGSPrivateAPI.h
//  SpaceRenamer
//
//  Bridging header for private macOS APIs to interact with Spaces.
//  These symbols are resolved at runtime from SkyLight framework.
//

#ifndef CGSPrivateAPI_h
#define CGSPrivateAPI_h

#include <CoreFoundation/CoreFoundation.h>

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

#endif /* CGSPrivateAPI_h */
