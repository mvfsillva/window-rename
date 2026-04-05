//
//  SpaceRenamer-Bridging-Header.h
//  SpaceRenamer
//
//  Bridging header to expose Objective-C/C APIs to Swift
//

#ifndef SpaceRenamer_Bridging_Header_h
#define SpaceRenamer_Bridging_Header_h

#include "CGSPrivateAPI.h"
#include <AppKit/AppKit.h>
#include <CoreServices/CoreServices.h>

// Re-export AXIsProcessTrusted for accessibility permission checking
extern Boolean AXIsProcessTrusted(void);

#endif /* SpaceRenamer_Bridging_Header_h */
