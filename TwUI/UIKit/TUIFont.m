/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "TUIFont.h"

@implementation TUIFont

- (id)initWithCTFont:(CTFontRef)f
{
	if((self = [super init]))
	{
		_ctFont = f;
		CFRetain(_ctFont);
	}
	return self;
}

- (void)dealloc
{
	if(_ctFont)
		CFRelease(_ctFont);
	[super dealloc];
}

static NSRange MakeNSRangeFromEndpoints(NSUInteger first, NSUInteger last) {
	return NSMakeRange(first, last - first + 1);
}

static NSFontDescriptor *arialUniDescFallback = nil;
static NSDictionary *CachedFontDescriptors = nil;

+ (void)initialize
{
	if(self == [TUIFont class]) {
		
		// fallback stuff prevents massive stalls
		NSRange range = MakeNSRangeFromEndpoints(0x2100, 0x214F);
		NSCharacterSet *letterlikeSymbolsSet = [NSCharacterSet characterSetWithRange:range];
		arialUniDescFallback = [[NSFontDescriptor fontDescriptorWithFontAttributes:
												   [NSDictionary dictionaryWithObjectsAndKeys:
													@"ArialUnicodeMS", NSFontNameAttribute, 
													letterlikeSymbolsSet, NSFontCharacterSetAttribute, 
													nil]] retain];
		NSString *normalFontName;
		NSString *lightFontName;
		NSString *mediumFontName;
		NSString *boldFontName;
		normalFontName = @"HelveticaNeue";
		lightFontName = @"HelveticaNeue-Light";
		mediumFontName = @"HelveticaNeue-Medium";
		boldFontName = @"HelveticaNeue-Bold";

		NSFontDescriptor *D_HelveticaNeue = [NSFontDescriptor fontDescriptorWithFontAttributes:
											  [NSDictionary dictionaryWithObjectsAndKeys:
											   normalFontName, NSFontNameAttribute,
											   [NSArray arrayWithObject:arialUniDescFallback], NSFontCascadeListAttribute,
											   nil]];
		NSFontDescriptor *D_HelveticaNeue_Light = [NSFontDescriptor fontDescriptorWithFontAttributes:
													[NSDictionary dictionaryWithObjectsAndKeys:
													 lightFontName, NSFontNameAttribute,
													 [NSArray arrayWithObject:arialUniDescFallback], NSFontCascadeListAttribute,
													 nil]];
		NSFontDescriptor *D_HelveticaNeue_Medium = [NSFontDescriptor fontDescriptorWithFontAttributes:
													 [NSDictionary dictionaryWithObjectsAndKeys:
													  mediumFontName, NSFontNameAttribute,
													  [NSArray arrayWithObject:arialUniDescFallback], NSFontCascadeListAttribute,
													  nil]];
		NSFontDescriptor *D_HelveticaNeue_Bold = [NSFontDescriptor fontDescriptorWithFontAttributes:
												   [NSDictionary dictionaryWithObjectsAndKeys:
													boldFontName, NSFontNameAttribute,
													[NSArray arrayWithObject:arialUniDescFallback], NSFontCascadeListAttribute,
													nil]];
		
		CachedFontDescriptors = [[NSDictionary dictionaryWithObjectsAndKeys:
								  D_HelveticaNeue, @"HelveticaNeue",
								  D_HelveticaNeue_Light, @"HelveticaNeue-Light",
								  D_HelveticaNeue_Medium, @"HelveticaNeue-Medium",
								  D_HelveticaNeue_Bold, @"HelveticaNeue-Bold",
								  nil] retain];
	}
}

+ (TUIFont *)fontWithName:(NSString *)fontName size:(CGFloat)fontSize
{
	NSFontDescriptor *desc = [CachedFontDescriptors objectForKey:fontName];
	if(!desc) {
		desc = [NSFontDescriptor fontDescriptorWithFontAttributes:
				[NSDictionary dictionaryWithObjectsAndKeys:
				 fontName, NSFontNameAttribute, 
				 [NSArray arrayWithObject:arialUniDescFallback], NSFontCascadeListAttribute, // oh thank you jesus
				 nil]];
		
	}
	CTFontRef font = CTFontCreateWithFontDescriptor((CTFontDescriptorRef)desc, fontSize, NULL);
	TUIFont *uiFont = [[TUIFont alloc] initWithCTFont:font];
	CFRelease(font);
	
	return [uiFont autorelease];
}

+ (TUIFont *)systemFontOfSize:(CGFloat)fontSize
{
	CTFontRef f = CTFontCreateUIFontForLanguage(kCTFontSystemFontType, fontSize, NULL);
	TUIFont *uifont = [[TUIFont alloc] initWithCTFont:f];
	CFRelease(f);
	return [uifont autorelease];
}

+ (TUIFont *)boldSystemFontOfSize:(CGFloat)fontSize
{
	CTFontRef f = CTFontCreateUIFontForLanguage(kCTFontEmphasizedSystemFontType, fontSize, NULL);
	TUIFont *uifont = [[TUIFont alloc] initWithCTFont:f];
	CFRelease(f);
	return [uifont autorelease];
}

- (NSString *)familyName { return [(NSString *)CTFontCopyFamilyName(_ctFont) autorelease]; }
- (NSString *)fontName { return [(NSString *)CTFontCopyPostScriptName(_ctFont) autorelease]; }
- (CGFloat)pointSize { return CTFontGetSize(_ctFont); }
- (CGFloat)ascender { return CTFontGetAscent(_ctFont); }
- (CGFloat)descender { return CTFontGetDescent(_ctFont); }
- (CGFloat)leading { return CTFontGetLeading(_ctFont); }
- (CGFloat)capHeight { return CTFontGetCapHeight(_ctFont); }
- (CGFloat)xHeight { return CTFontGetXHeight(_ctFont); }

- (TUIFont *)fontWithSize:(CGFloat)fontSize
{
	return nil;
}

- (CTFontRef)ctFont
{
	return _ctFont;
}


/*
 deprecated
 */

+ (void)loadFontData:(NSData *)fontData
{
	ATSFontContainerRef container;
	OSStatus err = ATSFontActivateFromMemory((void *)[fontData bytes], 
											 [fontData length],
											 kATSFontContextLocal,
											 kATSFontFormatUnspecified,
											 NULL,
											 kATSOptionFlagsDefault,
											 &container);
	
	if(err != noErr)
		NSLog(@"failed to load font into memory");
	
	ATSFontRef fontRefs[100];
	ItemCount fontCount;
	err = ATSFontFindFromContainer(container,
								   kATSOptionFlagsDefault,
								   100,
								   fontRefs,
								   &fontCount);
	
	if(err != noErr || fontCount < 1 ){
		NSLog(@"font could not be loaded.");
	} else{
		NSString *fontName;
		err = ATSFontGetPostScriptName(fontRefs[0],
									   kATSOptionFlagsDefault,
									   (CFStringRef *)(&fontName));
		NSLog(@"font %@ loaded", fontName);
	}
}

+ (void)loadBundledFonts
{
	[self loadFontData:[NSData dataWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Chicago-Bold.ttf"]]];
	[self loadFontData:[NSData dataWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"pixChicago.ttf"]]];
}

@end
