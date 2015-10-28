#import <objc/runtime.h>

#import "InputFix.h"
#import "org_oxygen_inputfixosx_InputFix__.h"

@implementation InputFix

static JavaVM *_jvm;
static jclass _InputFix;
static jmethodID _insertText;
static jmethodID _executeCommand;

static JNIEnv *attachCurrentThread(void)
{
    JNIEnv *env;
    (*_jvm)->AttachCurrentThread(_jvm, (void **)&env, NULL);
    return env;
}

/* NSTextInputClient implementations */

- (void)unmarkText {}
- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {}

- (BOOL)hasMarkedText { return NO; }
- (NSRange)markedRange { return (NSRange){NSNotFound, 0}; }
- (NSRange)selectedRange { return (NSRange){NSNotFound, 0}; }
- (NSUInteger)characterIndexForPoint:(NSPoint)_ { return NSNotFound; }
- (NSArray<NSString *> *)validAttributesForMarkedText { return nil; }

- (NSRect)firstRectForCharacterRange:(NSRange)_1 actualRange:(NSRangePointer)_2 { return NSZeroRect; }
- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)_1 actualRange:(NSRangePointer)_2 { return nil; }

- (void)doCommandBySelector:(SEL)selector
{
    JNIEnv *env = attachCurrentThread();
    jstring command = (*env)->NewStringUTF(env, sel_getName(selector));

    (*env)->CallStaticVoidMethod(env, _InputFix, _executeCommand, command);
    (*env)->DeleteLocalRef(env, command);
}

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange
{
    JNIEnv *env = attachCurrentThread();
    jstring text = (*env)->NewStringUTF(env, [(NSString *)string UTF8String]);

    (*env)->CallStaticVoidMethod(env, _InputFix, _insertText, text);
    (*env)->DeleteLocalRef(env, text);
}

static void addMethod(Class target, Class self, SEL sel)
{
    Method method = class_getInstanceMethod(self, sel);
    class_addMethod(target, sel, class_getMethodImplementation(self, sel), method_getTypeEncoding(method));
}

/* InputFix implementations */

static bool _enabled = false;
static bool _keyboard[65536] = {false};

+ (void)hook
{
    Class class = objc_getClass("MacOSXOpenGLView");

    addMethod(class, [self class], @selector(keyUpHook:));
    addMethod(class, [self class], @selector(keyDownHook:));

    class_addProtocol(class, objc_getProtocol("NSTextInputClient"));
    method_exchangeImplementations(class_getInstanceMethod(class, @selector(keyUp:)), class_getInstanceMethod(class, @selector(keyUpHook:)));
    method_exchangeImplementations(class_getInstanceMethod(class, @selector(keyDown:)), class_getInstanceMethod(class, @selector(keyDownHook:)));

    addMethod(class, [self class], @selector(unmarkText));
    addMethod(class, [self class], @selector(markedRange));
    addMethod(class, [self class], @selector(hasMarkedText));
    addMethod(class, [self class], @selector(selectedRange));
    addMethod(class, [self class], @selector(doCommandBySelector:));
    addMethod(class, [self class], @selector(characterIndexForPoint:));
    addMethod(class, [self class], @selector(insertText:replacementRange:));
    addMethod(class, [self class], @selector(validAttributesForMarkedText));
    addMethod(class, [self class], @selector(firstRectForCharacterRange:actualRange:));
    addMethod(class, [self class], @selector(setMarkedText:selectedRange:replacementRange:));
    addMethod(class, [self class], @selector(attributedSubstringForProposedRange:actualRange:));
}

+ (void)enable
{
    _enabled = true;
}

+ (void)disable
{
    _enabled = false;
}

- (void)keyUpHook:(NSEvent *)event
{
    if (!_enabled || _keyboard[event.keyCode])
    {
        [self keyUpHook:event];
        _keyboard[event.keyCode] = false;
    }
}

- (void)keyDownHook:(NSEvent *)event
{
    if (!_enabled)
    {
        [self keyDownHook:event];
        _keyboard[event.keyCode] = true;
    }
    else if (!_keyboard[event.keyCode])
    {
        /* forward to input manager */
        [self.inputContext handleEvent:event];
    }
}

@end

JNIEXPORT void JNICALL Java_org_oxygen_inputfixosx_InputFix_00024_patchKeyEvents(JNIEnv *env, jobject self)
{
    [InputFix hook];
}

JNIEXPORT void JNICALL Java_org_oxygen_inputfixosx_InputFix_00024_enableInputMethod(JNIEnv *env, jobject self)
{
    [InputFix enable];
}

JNIEXPORT void JNICALL Java_org_oxygen_inputfixosx_InputFix_00024_disableInputMethod(JNIEnv *env, jobject self)
{
    [InputFix disable];
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved)
{
    JNIEnv *env;
    (*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_8);

    _jvm = vm;
    _InputFix = (*env)->FindClass(env, "org/oxygen/inputfixosx/InputFix");
    _insertText = (*env)->GetStaticMethodID(env, _InputFix, "insertText", "(Ljava/lang/String;)V");
    _executeCommand = (*env)->GetStaticMethodID(env, _InputFix, "executeCommand", "(Ljava/lang/String;)V");
    return JNI_VERSION_1_8;
}
