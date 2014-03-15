//
//  DCScrollViewNavigationView.m
//
//  Created by Hirohisa Kawasaki on 2014/03/16.
//  Copyright (c) 2014年 Hirohisa Kawasaki. All rights reserved.
//

#import "DCScrollViewNavigationView.h"
#import "DCScrollView+Logic.h"
#import "DCScrollViewNavigationViewCell.h"


@interface DCScrollViewNavigationViewInnerScrollView : UIScrollView
@end

@implementation DCScrollViewNavigationViewInnerScrollView

#pragma mark - UIResponder

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.superview) {
        [self.superview touchesEnded:touches withEvent:event];
    }
}

@end


@interface DCScrollViewNavigationView () <UIScrollViewDelegate>

@property (nonatomic, readonly) DCScrollViewNavigationViewInnerScrollView *scrollView;

@end

@implementation DCScrollViewNavigationView

- (id)initWithFrame:(CGRect)frame frameAtScrollView:(CGRect)frameAtScrollView

{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.focusedCenter = NO;

        // initialize scrollView
        _scrollView = [[DCScrollViewNavigationViewInnerScrollView alloc] initWithFrame:CGRectZero];
        self.scrollView.backgroundColor = [UIColor purpleColor];
        self.scrollView.delegate = self;
        self.scrollView.clipsToBounds = NO;
        self.scrollView.pagingEnabled = YES;
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator   = NO;
        self.scrollView.scrollsToTop = NO;
        [self addSubview:self.scrollView];

        [self setFrameAtScrollView:frameAtScrollView];
    }
    return self;
}

- (void)setFrameAtScrollView:(CGRect)frame
{
    self.scrollView.frame = frame;
    self.scrollView.center = (CGPoint) {
        .x = CGRectGetWidth(self.bounds)/2,
        .y = CGRectGetHeight(self.bounds)/2
    };
}

#pragma mark - generate

- (DCScrollViewNavigationViewCell *)cellAtIndex:(NSInteger)index
{
    for (DCScrollViewNavigationViewCell *cell in self.visibleCells) {
        if (cell.index == index) {
            return cell;
        }
    }

    NSUInteger length = [self.dataSource numberOfCellsInDCScrollViewNavigationView:self];
    NSInteger relativedIndex = [@(index) relativedIntegerValueWithLength:length];
    DCScrollViewNavigationViewCell *cell = [self.dataSource dcscrollViewNavigationView:self cellAtIndex:relativedIndex];
    cell.index = index;

    return cell;
}

#pragma mark - reloadData

- (void)reloadData
{
    for (DCScrollViewNavigationViewCell *cell in self.visibleCells) {
        [cell removeFromSuperview];
    }
    self.visibleCells = [@[] mutableCopy];

    NSUInteger length = ([self.dataSource numberOfCellsInDCScrollViewNavigationView:self] > 1)?11:1;
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.scrollView.frame) * length, CGRectGetHeight(self.frame));
    [self renderCells];
    CGFloat x = CGRectGetWidth(self.scrollView.bounds) * ([self.scrollView centerPage]);
    [self.scrollView setContentOffset:CGPointMake(x, 0) animated:NO];
}

- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated
{
    NSInteger diff = page - self.page;
    if (abs(diff)) {
        if (self.focusedCenter) {
            [self changeCellsWithHighlited:NO];
        }
        if ([self.dataSource numberOfCellsInDCScrollViewNavigationView:self] > 1) {
            CGFloat x = CGRectGetWidth(self.scrollView.bounds) * diff;
            [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x + x, 0) animated:YES];
        }
        _page = page;
    }
}

#pragma mark - rendering

- (void)renderCells
{
    NSMutableArray *cells = [@[] mutableCopy];
    // remove not visibled cells
    for (DCScrollViewNavigationViewCell *cell in self.visibleCells) {
        if (cell.index < self.page-[self.scrollView centerPage] || cell.index > self.page+[self.scrollView centerPage]) {
            [cell removeFromSuperview];
        } else {
            [cells addObject:cell];
        }
    }

    // add cells to visibled
    self.visibleCells = [cells mutableCopy];
    int i = 0;
    for (int index=self.page-[self.scrollView centerPage]; index<=self.page+[self.scrollView centerPage]; index++) {
        DCScrollViewNavigationViewCell *cell = [self cellAtIndex:index];
        cell.frame = [self frameForTitleAtIndex:i];
        if (![self.visibleCells containsObject:cell]) {
            [self.visibleCells addObject:cell];
        }
        if (![cell isDescendantOfView:self]) {
            [self.scrollView addSubview:cell];
        }
        i++;
    }
    [self switchHighlited];
}

- (CGRect)frameForTitleAtIndex:(NSInteger)index
{
    CGSize size = self.scrollView.bounds.size;
    return (CGRect) {
        .origin.x = (size.width) * (index),
        .origin.y = 0,
        .size     = size
    };
}

- (void)changeCellsWithHighlited:(BOOL)highlited
{
    for (DCScrollViewNavigationViewCell *cell in self.visibleCells) {
        cell.highlighted = highlited;
    }
}

- (void)switchHighlited
{
    for (DCScrollViewNavigationViewCell *cell in self.visibleCells) {
        cell.highlighted = (cell.index == self.page);
    }
}

#pragma mark - UIResponder

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint point = [[touches anyObject] locationInView:self];
    if ([self.dataSource numberOfCellsInDCScrollViewNavigationView:self] > 1) {
        BOOL isRight = CGRectGetMaxX(self.scrollView.frame) < point.x;
        BOOL isLeft  = CGRectGetMinX(self.scrollView.frame) > point.x;
        if (isRight) {
            [self scrollToPage:self.page+1 animated:YES];
        } else if (isLeft) {
            [self scrollToPage:self.page-1 animated:YES];
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.y) {
        scrollView.contentOffset = (CGPoint) {
            .x = scrollView.contentOffset.x,
            .y = 0
        };
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.focusedCenter) {
        [self changeCellsWithHighlited:NO];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    int adjust = [scrollView reservingPage] - [scrollView centerPage];
    _page = self.page + adjust;
    [self renderCells];
    [self scrollToCenterWithAnimated:NO];
    if ([self.delegate respondsToSelector:@selector(dcscrollViewNavigationViewDidEndDecelerating:)]) {
        [self.delegate dcscrollViewNavigationViewDidEndDecelerating:self];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self renderCells];
    [self scrollToCenterWithAnimated:NO];
    if ([self.delegate respondsToSelector:@selector(dcscrollViewNavigationViewDidEndScrollingAnimation:)]) {
        [self.delegate dcscrollViewNavigationViewDidEndScrollingAnimation:self];
    }
}

- (void)scrollToCenterWithAnimated:(BOOL)animated
{
    CGFloat x = CGRectGetWidth(self.scrollView.bounds) * ([self.scrollView centerPage]);
    [self.scrollView setContentOffset:CGPointMake(x, 0) animated:animated];
}

#pragma mark - touch

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if ([self pointInside:point withEvent:event]) {
        return self.scrollView;
    }
    return [super hitTest:point withEvent:event];
}

@end