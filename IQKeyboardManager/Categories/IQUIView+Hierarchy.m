//!
//  UIView+Hierarchy.m
// https://github.com/hackiftekhar/IQKeyboardManager
// Copyright (c) 2013-16 Iftekhar Qurashi.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "IQUIView+Hierarchy.h"

#import <UIKit/UICollectionView.h>

#import <UIKit/UITableView.h>
#import <UIKit/UITextView.h>
#import <UIKit/UITextField.h>
#import <UIKit/UISearchBar.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIWindow.h>

#import <objc/runtime.h>

#import "IQNSArray+Sort.h"

@implementation UIView (IQ_UIView_Hierarchy)


-(void)_setIsAskingCanBecomeFirstResponder:(BOOL)isAskingCanBecomeFirstResponder
{
    objc_setAssociatedObject(self, @selector(isAskingCanBecomeFirstResponder), @(isAskingCanBecomeFirstResponder), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(BOOL)isAskingCanBecomeFirstResponder
{
    NSNumber *isAskingCanBecomeFirstResponder = objc_getAssociatedObject(self, @selector(isAskingCanBecomeFirstResponder));
    return [isAskingCanBecomeFirstResponder boolValue];
}

/// 遍历nextResponder 找到viewController
-(UIViewController*)viewController
{
    UIResponder *nextResponder =  self;
    
    do
    {
        nextResponder = [nextResponder nextResponder];

        if ([nextResponder isKindOfClass:[UIViewController class]])
            return (UIViewController*)nextResponder;

    } while (nextResponder != nil);

    return nil;
}

/// 返回自己所在的视图控制器的层次中最底层的控制器 即最后一个被presented的ViewController
-(UIViewController *)topMostController
{
    NSMutableArray *controllersHierarchy = [[NSMutableArray alloc] init];
    
    UIViewController *topController = self.window.rootViewController;
    
    if (topController)
    {
        [controllersHierarchy addObject:topController];
    }
    
    // presentedViewController
    while ([topController presentedViewController]) {
        
        topController = [topController presentedViewController];
        [controllersHierarchy addObject:topController];
    }
    
    // 自己所在的试图控制器
    UIResponder *matchController = [self viewController];
    
    // 往上找matchController的上一个控制器 直到找到摸个属于controllersHierarchy的视图控制器
    while (matchController != nil && [controllersHierarchy containsObject:matchController] == NO) {
        // 遍历nextResponder 找到上一个UIViewController
        do
        {
            //  UIView implements this method by returning the UIViewController object that manages it (if it has one) or its superview (if it doesn’t)
            //  UIViewController implements the method by returning its view’s superview
            matchController = [matchController nextResponder];
            
        } while (matchController != nil && [matchController isKindOfClass:[UIViewController class]] == NO);
    }
    
    return (UIViewController*)matchController;
}

/// 查找父视图中classType类的实例
-(UIView*)superviewOfClassType:(Class)classType
{
    UIView *superview = self.superview;
    
    while (superview)
    {
        static Class UITableViewCellScrollViewClass = Nil;   //UITableViewCell
        static Class UITableViewWrapperViewClass = Nil;      //UITableViewCell
        static Class UIQueuingScrollViewClass = Nil;         //UIPageViewController

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            UITableViewCellScrollViewClass      = NSClassFromString(@"UITableViewCellScrollView");
            UITableViewWrapperViewClass         = NSClassFromString(@"UITableViewWrapperView");
            UIQueuingScrollViewClass            = NSClassFromString(@"_UIQueuingScrollView");
        });
        if ([superview isKindOfClass:classType] &&
            ([superview isKindOfClass:UITableViewCellScrollViewClass] == NO) &&
            ([superview isKindOfClass:UITableViewWrapperViewClass] == NO) &&
            ([superview isKindOfClass:UIQueuingScrollViewClass] == NO))
        {
            return superview;
        }
        else    superview = superview.superview;
    }
    
    return nil;
}

/// 是否可以成为第一响应者
/// 并不完美。。
-(BOOL)_IQcanBecomeFirstResponder
{
    [self _setIsAskingCanBecomeFirstResponder:YES];
    BOOL _IQcanBecomeFirstResponder = ([self canBecomeFirstResponder] && [self isUserInteractionEnabled] && ![self isHidden] && [self alpha]!=0.0 && ![self isAlertViewTextField]  && ![self isSearchBarTextField]);
    
    if (_IQcanBecomeFirstResponder == YES)
    {
        if ([self isKindOfClass:[UITextField class]])
        {
            _IQcanBecomeFirstResponder = [(UITextField*)self isEnabled];
        }
        else if ([self isKindOfClass:[UITextView class]])
        {
            _IQcanBecomeFirstResponder = [(UITextView*)self isEditable];
        }
    }
    
    [self _setIsAskingCanBecomeFirstResponder:NO];
    
    return _IQcanBecomeFirstResponder;
}

/// 返回父视图的子视图中所有的输入框 包括自己 不包含子视图的子视图
- (NSArray*)responderSiblings
{
    //	Getting all siblings
    NSArray *siblings = self.superview.subviews;
    
    //Array of (UITextField/UITextView's).
    NSMutableArray *tempTextFields = [[NSMutableArray alloc] init];
    
    for (UIView *textField in siblings)
        if ([textField _IQcanBecomeFirstResponder])
            [tempTextFields addObject:textField];
    
    return tempTextFields;
}

/// 包括自己 包含子视图的子视图 这些输入框之间也可能是父子关系
- (NSArray*)deepResponderViews
{
    NSMutableArray *textFields = [[NSMutableArray alloc] init];
    
    for (UIView *textField in self.subviews)
    {
        if ([textField _IQcanBecomeFirstResponder])
        {
            [textFields addObject:textField];
        }
        
        //Sometimes there are hidden or disabled views and textField inside them still recorded, so we added some more validations here (Bug ID: #458)
        //Uncommented else (Bug ID: #625)
        if (textField.subviews.count && [textField isUserInteractionEnabled] && ![textField isHidden] && [textField alpha]!=0.0)
        {
            [textFields addObjectsFromArray:[textField deepResponderViews]];
        }
    }

    //subviews are returning in incorrect order. Sorting according the frames 'y'.
    return [textFields sortedArrayUsingComparator:^NSComparisonResult(UIView *view1, UIView *view2) {
        
        CGRect frame1 = [view1 convertRect:view1.bounds toView:self];
        CGRect frame2 = [view2 convertRect:view2.bounds toView:self];
        
        CGFloat x1 = CGRectGetMinX(frame1);
        CGFloat y1 = CGRectGetMinY(frame1);
        CGFloat x2 = CGRectGetMinX(frame2);
        CGFloat y2 = CGRectGetMinY(frame2);
        
        if (y1 < y2)  return NSOrderedAscending;
        
        else if (y1 > y2) return NSOrderedDescending;
        
        //Else both y are same so checking for x positions
        else if (x1 < x2)  return NSOrderedAscending;
        
        else if (x1 > x2) return NSOrderedDescending;
        
        else    return NSOrderedSame;
    }];

    return textFields;
}

/// toView为nil 默认为self.window
-(CGAffineTransform)convertTransformToView:(UIView*)toView
{
    if (toView == nil)
    {
        toView = self.window;
    }
    
    CGAffineTransform myTransform = CGAffineTransformIdentity;
    
    //My Transform
    {
        UIView *superView = [self superview];
        
        if (superView)  myTransform = CGAffineTransformConcat(self.transform, [superView convertTransformToView:nil]);
        else            myTransform = self.transform;
    }
    
    CGAffineTransform viewTransform = CGAffineTransformIdentity;
    
    //view Transform
    {
        UIView *superView = [toView superview];
        
        if (superView)  viewTransform = CGAffineTransformConcat(toView.transform, [superView convertTransformToView:nil]);
        else if (toView)  viewTransform = toView.transform;
    }
    
    return CGAffineTransformConcat(myTransform, CGAffineTransformInvert(viewTransform));
}

/// 根视图为0 递归
- (NSInteger)depth
{
    NSInteger depth = 0;
    
    if ([self superview])
    {
        depth = [[self superview] depth] + 1;
    }
    
    return depth;
}

/// 用于打印子视图调试信息 递归
- (NSString *)subHierarchy
{
    NSMutableString *debugInfo = [[NSMutableString alloc] initWithString:@"\n"];
    NSInteger depth = [self depth];
    
    for (int counter = 0; counter < depth; counter ++)  [debugInfo appendString:@"|  "];
    
    [debugInfo appendString:[self debugHierarchy]];
    
    for (UIView *subview in self.subviews)
    {
        [debugInfo appendString:[subview subHierarchy]];
    }
    
    return debugInfo;
}

- (NSString *)superHierarchy
{
    NSMutableString *debugInfo = [[NSMutableString alloc] init];

    if (self.superview)
    {
        [debugInfo appendString:[self.superview superHierarchy]];
    }
    else
    {
        [debugInfo appendString:@"\n"];
    }
    
    NSInteger depth = [self depth];
    
    for (int counter = 0; counter < depth; counter ++)  [debugInfo appendString:@"|  "];
    
    [debugInfo appendString:[self debugHierarchy]];

    [debugInfo appendString:@"\n"];
    
    return debugInfo;
}

/// 用于打印视图层次
/// 类名: (x,y,w,h) {contentSize: (w,h)} {transform: transformString}
/// {}内的内容不一定有
-(NSString *)debugHierarchy
{
    NSMutableString *debugInfo = [[NSMutableString alloc] init];

    [debugInfo appendFormat:@"%@: ( %.0f, %.0f, %.0f, %.0f )",NSStringFromClass([self class]), CGRectGetMinX(self.frame), CGRectGetMinY(self.frame), CGRectGetWidth(self.frame), CGRectGetHeight(self.frame)];
    
    if ([self isKindOfClass:[UIScrollView class]])
    {
        UIScrollView *scrollView = (UIScrollView*)self;
        [debugInfo appendFormat:@"%@: ( %.0f, %.0f )",NSStringFromSelector(@selector(contentSize)),scrollView.contentSize.width,scrollView.contentSize.height];
    }
    
    if (CGAffineTransformEqualToTransform(self.transform, CGAffineTransformIdentity) == false)
    {
        [debugInfo appendFormat:@"%@: %@",NSStringFromSelector(@selector(transform)),NSStringFromCGAffineTransform(self.transform)];
    }
    
    return debugInfo;
}

-(BOOL)isSearchBarTextField
{
    static Class UISearchBarTextFieldClass = Nil;        //UISearchBar

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UISearchBarTextFieldClass           = NSClassFromString(@"UISearchBarTextField");
    });
    return ([self isKindOfClass:UISearchBarTextFieldClass] || [self isKindOfClass:[UISearchBar class]]);
}

/// UIAlertSheet或者UIAlertView上的textField
-(BOOL)isAlertViewTextField
{
    //Special textFields,textViews,scrollViews
    static Class UIAlertSheetTextFieldClass = Nil;       //UIAlertView
    static Class UIAlertSheetTextFieldClass_iOS8 = Nil;  //UIAlertView

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIAlertSheetTextFieldClass          = NSClassFromString(@"UIAlertSheetTextField");
        UIAlertSheetTextFieldClass_iOS8     = NSClassFromString(@"_UIAlertControllerTextField");
    });
    
    return ([self isKindOfClass:UIAlertSheetTextFieldClass] || [self isKindOfClass:UIAlertSheetTextFieldClass_iOS8]);
}

@end


@implementation NSObject (IQ_Logging)

-(NSString *)_IQDescription
{
    return [NSString stringWithFormat:@"<%@ %p>",NSStringFromClass([self class]),self];
}

@end
