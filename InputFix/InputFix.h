#import <Cocoa/Cocoa.h>

@interface InputFix : NSView <NSTextInputClient>

+ (void)hook;
+ (void)enable;
+ (void)disable;

- (void)keyUpHook:(NSEvent *)event;
- (void)keyDownHook:(NSEvent *)event;

@end
