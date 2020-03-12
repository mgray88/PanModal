//
//  PanModalPresentationAnimator.swift
//  PanModal
//
//  Copyright © 2019 Tiny Speck, Inc. All rights reserved.
//

#if os(iOS)
import UIKit

/**
 Handles the animation of the presentedViewController as it is presented or dismissed.

 This is a vertical animation that
 - Animates up from the bottom of the screen
 - Dismisses from the top to the bottom of the screen

 This can be used as a standalone object for transition animation,
 but is primarily used in the PanModalPresentationDelegate for handling pan modal transitions.

 - Note: The presentedViewController can conform to PanModalPresentable to adjust
 it's starting position through manipulating the shortFormHeight
 */

public class PanModalPresentationAnimator: NSObject {

    /**
     Enum representing the possible transition styles
     */
    public enum TransitionStyle {
        case presentation
        case dismissal
    }

    // MARK: - Properties

    /**
     The transition style
     */
    private let transitionStyle: TransitionStyle

    /**
     Haptic feedback generator (during presentation)
     */
    private var feedbackGenerator: UISelectionFeedbackGenerator?

    // MARK: - Initializers

    required public init(transitionStyle: TransitionStyle) {
        self.transitionStyle = transitionStyle
        super.init()

        /**
         Prepare haptic feedback, only during the presentation state
         */
        if case .presentation = transitionStyle {
            feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator?.prepare()
        }
    }

    /**
     Animate presented view controller presentation
     */
    private func animatePresentation(transitionContext: UIViewControllerContextTransitioning) {

        guard
            let toVC = transitionContext.viewController(forKey: .to),
            let fromVC = transitionContext.viewController(forKey: .from)
            else { return }

        let presentable = panModalLayoutType(from: transitionContext)

        // Calls viewWillAppear and viewWillDisappear
//        fromVC.beginAppearanceTransition(false, animated: true)
        
        // Presents the view in shortForm position, initially
        let yPos: CGFloat = presentable?.shortFormYPos ?? 0.0

        // Use panView as presentingView if it already exists within the containerView
        let panView: UIView = transitionContext.containerView.panContainerView ?? toVC.view

        // Move presented view offscreen (from the bottom)
        panView.frame = transitionContext.finalFrame(for: toVC)
        panView.frame.origin.y = transitionContext.containerView.frame.height

        // Haptic feedback
        if presentable?.isHapticFeedbackEnabled == true {
            feedbackGenerator?.selectionChanged()
        }

        let presentingView = fromVC.view.snapshotView(afterScreenUpdates: false)!
        presentingView.tag = 99

        if #available(iOS 11.0, *),
            let inset = UIApplication.shared.keyWindow?.safeAreaInsets.bottom,
            inset > 0 {

            let corners: UIRectCorner = [.topLeft, .topRight]

            let borderMask = CAShapeLayer()
            borderMask.frame = presentingView.bounds
            borderMask.path = UIBezierPath(
                roundedRect: presentingView.bounds,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: 38.5, height: 38.5)
            ).cgPath
            presentingView.layer.mask = borderMask
            presentingView.clipsToBounds = true
        }

        transitionContext.containerView.addSubview(presentingView)
        transitionContext.containerView.sendSubviewToBack(presentingView)

        PanModalAnimator.animate({
            presentingView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            panView.frame.origin.y = yPos
        }, config: presentable) { [weak self] didComplete in
            // Calls viewDidAppear and viewDidDisappear
//            fromVC.endAppearanceTransition()
            transitionContext.completeTransition(didComplete)
            self?.feedbackGenerator = nil
        }
    }

    /**
     Animate presented view controller dismissal
     */
    private func animateDismissal(transitionContext: UIViewControllerContextTransitioning) {

        guard
            let toVC = transitionContext.viewController(forKey: .to),
            let fromVC = transitionContext.viewController(forKey: .from)
            else { return }
        
        let presentable = panModalLayoutType(from: transitionContext)
        let panView: UIView = transitionContext.containerView.panContainerView ?? fromVC.view
        let presentingView = transitionContext.containerView.subviews.first { $0.tag == 99 }

        PanModalAnimator.animate({
            presentingView?.transform = CGAffineTransform.identity
            panView.frame.origin.y = transitionContext.containerView.frame.height
        }, config: presentable) { didComplete in
            toVC.view.layer.mask = nil
            toVC.view.layer.masksToBounds = false
            fromVC.view.removeFromSuperview()
            transitionContext.completeTransition(didComplete)
        }
    }

    /**
     Extracts the PanModal from the transition context, if it exists
     */
    private func panModalLayoutType(from context: UIViewControllerContextTransitioning) -> PanModalPresentable.LayoutType? {
        switch transitionStyle {
        case .presentation:
            return context.viewController(forKey: .to) as? PanModalPresentable.LayoutType
        case .dismissal:
            return context.viewController(forKey: .from) as? PanModalPresentable.LayoutType
        }
    }

}

// MARK: - UIViewControllerAnimatedTransitioning Delegate

extension PanModalPresentationAnimator: UIViewControllerAnimatedTransitioning {

    /**
     Returns the transition duration
     */
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {

        guard
            let context = transitionContext,
            let presentable = panModalLayoutType(from: context)
            else { return PanModalAnimator.Constants.defaultTransitionDuration }

        return presentable.transitionDuration
    }

    /**
     Performs the appropriate animation based on the transition style
     */
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        switch transitionStyle {
        case .presentation:
            animatePresentation(transitionContext: transitionContext)
        case .dismissal:
            animateDismissal(transitionContext: transitionContext)
        }
    }

}
#endif
