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
            
            NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
            
            if (editMenuItem)
            {
                [[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
                
                // Convert To Dot Notation
                NSMenuItem *dotNotationMenuItem = [[NSMenuItem alloc] initWithTitle:@"Convert To Dot Notation" action:@selector(convertToDotNotation) keyEquivalent:@"x"];
                [dotNotationMenuItem setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
                [dotNotationMenuItem setTarget:self];
                [[editMenuItem submenu] addItem:dotNotationMenuItem];
                
                // Add a comment with name and date
                NSMenuItem *commentMenuItem = [[NSMenuItem alloc] initWithTitle:@"Add a comment" action:@selector(addComment) keyEquivalent:@"c"];
                [commentMenuItem setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
                [commentMenuItem setTarget:self];
                [[editMenuItem submenu] addItem:commentMenuItem];
                
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
    NSString *comment = [NSString stringWithFormat:@"// <#comment#> [yufei %@]", dateString];
    
    NSRange selectedRange = ((NSValue *)[[textView selectedRanges] firstObject]).rangeValue;
    NSUInteger insertionPoint = selectedRange.location;
    NSUInteger selectedTextLenght = selectedRange.length;
    
    if (selectedTextLenght > 0) // have text selected
    {
        NSRange lineRange = [textView.textStorage.string lineRangeForRange:selectedRange];
        NSString *stringAtLines = [textView.textStorage.string substringWithRange:lineRange];
        
        NSMutableCharacterSet *noneWhitespaceCharSet = [NSMutableCharacterSet whitespaceCharacterSet];
        [noneWhitespaceCharSet addCharactersInRange:NSMakeRange((unsigned int)'\t', 1)];
        [noneWhitespaceCharSet invert];
        
        NSRange firstCharRange = [stringAtLines rangeOfCharacterFromSet:noneWhitespaceCharSet options:0];
        if (firstCharRange.location != NSNotFound)
        {
            NSUInteger numberOfWhitespace = 0;
            NSString *stringBefore1stLetter = [stringAtLines substringToIndex:firstCharRange.location];
            for (NSUInteger idx = 0; idx < stringBefore1stLetter.length; idx++) {
                numberOfWhitespace += ([stringBefore1stLetter characterAtIndex:idx] == '\t') ? 4 : 1; // deal with 'tab' symbol
            }
            
            NSMutableString *whiteSpaces = [NSMutableString string];
            for (NSUInteger i = 0; i < numberOfWhitespace; i++) {
                [whiteSpaces appendString:@" "];
            }
            NSMutableString *newString = [[NSMutableString alloc] initWithFormat:@"%@/* <#comment#> [yufei %@]\n%@ *\n%@%@ */\n", whiteSpaces, dateString, whiteSpaces, stringAtLines, whiteSpaces];
            if ([textView shouldChangeTextInRange:lineRange replacementString:newString])
            {
                [textView.textStorage replaceCharactersInRange:lineRange withAttributedString:[[NSAttributedString alloc] initWithString:newString]];
                [textView setSelectedRange:NSMakeRange(lineRange.location + whiteSpaces.length + 3, @"<#comment#>".length)];
                [textView didChangeText];
            }
        }
    }
    else
    {
        if ([textView shouldChangeTextInRange:NSMakeRange(insertionPoint, 0) replacementString:comment])
        {
            [textView.textStorage insertAttributedString:[[NSAttributedString alloc] initWithString:comment] atIndex:insertionPoint];
            [textView setSelectedRange:NSMakeRange(insertionPoint + 3, @"<#comment#>".length)];
            [textView didChangeText];
        }
    }
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
        /* this is a comment [yufei]
         *
         NSRange range = [[selectedRanges firstObject] rangeValue];
         NSRange lineRange = [textView.textStorage.string lineRangeForRange:range];
         NSString *line = [textView.textStorage.string substringWithRange:lineRange];
         */
        
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
