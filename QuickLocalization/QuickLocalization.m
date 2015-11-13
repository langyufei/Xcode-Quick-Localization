//
//  QuickLocalization.m
//  QuickLocalization
//
//  Created by Zitao Xiong on 5/12/13.
//  Copyright (c) 2013 nanaimostudio. All rights reserved.
//

#import "QuickLocalization.h"
#import "RCXcode.h"

@interface QuickLocalization ()
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@end

@implementation QuickLocalization

static id sharedPlugin = nil;


+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

- (id)init
{
    if (self = [super init])
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            NSMenuItem *viewMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
            
            if (viewMenuItem)
            {
                [[viewMenuItem submenu] addItem:[NSMenuItem separatorItem]];
                
                // Convert To Dot Notation
                NSMenuItem *dotNotationMenuItem = [[NSMenuItem alloc] initWithTitle:@"Convert To Dot Notation" action:@selector(convertToDotNotation) keyEquivalent:@"x"];
                [dotNotationMenuItem setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
                [dotNotationMenuItem setTarget:self];
                [[viewMenuItem submenu] addItem:dotNotationMenuItem];
                
                // Add a comment with name and date
                NSMenuItem *commentMenuItem = [[NSMenuItem alloc] initWithTitle:@"Add a comment" action:@selector(addComment) keyEquivalent:@"c"];
                [commentMenuItem setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
                [commentMenuItem setTarget:self];
                [[viewMenuItem submenu] addItem:commentMenuItem];
                
                // NSString *fmt = [NSDateFormatter dateFormatFromTemplate:@"dMMMHm" options:0 locale:[NSLocale currentLocale]];
                if (!self.dateFormatter) {
                    self.dateFormatter = [[NSDateFormatter alloc] init];
                }
                self.dateFormatter.dateFormat = @"MMM d<#@H:mm#>";
            }
        }];
    }
    
    return self;
}

- (void)addComment
{
    IDESourceCodeDocument *document = [RCXcode currentSourceCodeDocument];
    NSTextView *textView = [RCXcode currentSourceCodeTextView];
    
    if (!document || !textView) {
        return;
    }
    
    NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
    NSString *comment = [NSString stringWithFormat:@" // <#comment#> [yufei %@]", dateString];
    
    NSInteger insertionPoint = [[[textView selectedRanges] objectAtIndex:0] rangeValue].location;
    [textView.textStorage insertAttributedString:[[NSAttributedString alloc] initWithString:comment] atIndex:insertionPoint];
    [textView setSelectedRange:NSMakeRange(insertionPoint + 4, @"<#comment#>".length)];
}

- (void)convertToDotNotation
{
    IDESourceCodeDocument *document = [RCXcode currentSourceCodeDocument];
    NSTextView *textView = [RCXcode currentSourceCodeTextView];
    
    if (!document || !textView) {
        return;
    }
    
    NSArray *selectedRanges = [textView selectedRanges];
    if (selectedRanges.count > 0)
    {
        NSRange range = [[selectedRanges firstObject] rangeValue];
        NSRange lineRange = [textView.textStorage.string lineRangeForRange:range];
        NSString *line = [textView.textStorage.string substringWithRange:lineRange];
        
        NSString *dotNotationRegex = @".*[.].*[ ]{0,}=[ ]{0,}.*[ ]{0,}\\;";
        NSString *messageNotationRegex = @"\\[[ ]{0,}(.*)\\sset(.*?)[ ]{0,}\\:[ ]{0,}(.*)\\]\\;";
        
        NSRegularExpression *dotNotationRex = [[NSRegularExpression alloc] initWithPattern:dotNotationRegex options:NSRegularExpressionCaseInsensitive error:nil];
        NSArray *dotNotationMatches = [dotNotationRex matchesInString:line options:0 range:NSMakeRange(0, line.length)];
        
        NSRegularExpression *MsgNotationRegex = [[NSRegularExpression alloc] initWithPattern:messageNotationRegex options:NSRegularExpressionCaseInsensitive error:nil];
        NSArray *msgNotationMatches = [MsgNotationRegex matchesInString:line options:0 range:NSMakeRange(0, line.length)];
        
        NSInteger addedLength = 0;
        
        for (NSTextCheckingResult *result in msgNotationMatches)
        {
            NSRange matchedRangeInLine = result.range;
            NSRange matchedRangeInDocument = NSMakeRange(lineRange.location + matchedRangeInLine.location + addedLength, matchedRangeInLine.length);
            NSString *string = [line substringWithRange:matchedRangeInLine];
            
            NSString *receiver = [line substringWithRange:[result rangeAtIndex:1]];
            NSString *property = [line substringWithRange:[result rangeAtIndex:2]];
            NSString *newValue = [line substringWithRange:[result rangeAtIndex:3]];
            
            if ([self isRange:matchedRangeInLine inSkipedRanges:dotNotationMatches]) {
                continue;
            }
            
            NSString *lowerCasePropertyFirstLetter = [[[property substringToIndex:1] lowercaseString] stringByAppendingString:[property substringFromIndex:1]];
            NSString *outputString = [NSString stringWithFormat:@"%@.%@ = %@;", receiver, lowerCasePropertyFirstLetter, newValue];
            
            addedLength = addedLength + outputString.length - string.length;
            
            if ([textView shouldChangeTextInRange:matchedRangeInDocument replacementString:outputString])
            {
                [textView.textStorage replaceCharactersInRange:matchedRangeInDocument withAttributedString:[[NSAttributedString alloc] initWithString:outputString]];
                [textView didChangeText];
            }
        }
    }
}

- (BOOL)isRange:(NSRange)range inSkipedRanges:(NSArray *)ranges
{
    for (int i = 0; i < [ranges count]; i++)
    {
        NSTextCheckingResult *result = [ranges objectAtIndex:i];
        NSRange skippedRange = result.range;
        
        if (skippedRange.location <= range.location && skippedRange.location + skippedRange.length > range.location + range.length)
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return YES;
}

@end
