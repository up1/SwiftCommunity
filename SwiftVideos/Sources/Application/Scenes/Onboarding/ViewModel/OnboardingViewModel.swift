//
//  Copyright © 2019 An Tran. All rights reserved.
//

import SwiftVideos_Core
import SuperArcNotificationBanner
import SuperArcStateView
import SuperArcCoreComponent
import SuperArcCoreUI
import SuperArcCore
import XCoordinator
import RxSwift
import RxCocoa

protocol OnboardingViewModelInput {}

protocol OnboardingViewModelOutput {
    var isReady: PublishSubject<Bool> { get set }
    var isUpdated: PublishSubject<Bool> { get set }
    var isCloned: PublishSubject<Bool> { get set }
}

protocol OnboardingViewModelApi {
    func prepareLocalRepository(shouldResetBeforeCloning: Bool)
}

protocol OnboardingViewModelType {
    var inputs: OnboardingViewModelInput { get }
    var outputs: OnboardingViewModelOutput { get }
    var apis: OnboardingViewModelApi { get }
}

extension OnboardingViewModelType where Self: OnboardingViewModelType & OnboardingViewModelInput & OnboardingViewModelOutput & OnboardingViewModelApi {

    var inputs: OnboardingViewModelInput {
        return self
    }

    var outputs: OnboardingViewModelOutput {
        return self
    }

    var apis: OnboardingViewModelApi {
        return self
    }
}

class OnboardingViewModel: CoordinatedDIViewModel<OnboardingRoute, OnboardingDependency>, OnboardingViewModelType, OnboardingViewModelInput, OnboardingViewModelOutput, OnboardingViewModelApi {

    // MARK: Properties

    // Public

    var isReady = PublishSubject<Bool>()
    var isUpdated = PublishSubject<Bool>()
    var isCloned = PublishSubject<Bool>()

    var toggleEmptyState = PublishSubject<StandardStateViewContext?>()
    var notification = PublishSubject<SuperArcNotificationBanner.Notification?>()

    // Private

    private let disposeBag = DisposeBag()

    // MARK: Initialization

    override init(router: AnyRouter<OnboardingRoute>, dependency: OnboardingDependency) {
        super.init(router: router, dependency: dependency)

        isReady
            .observeOn(MainScheduler.instance)
            .subscribe { event in
                guard let isReady = event.element, isReady else {
                    return
                }
                self.router.trigger(.dashboard)
            }.disposed(by: disposeBag)
    }

    // MARK: APIs

    func prepareLocalRepository(shouldResetBeforeCloning: Bool) {

        // Check if the local repository is existing.
        guard !dependency.gitService.open() else {
            updateLocalRepository()
            return
        }

        // If the local repository doesn't exist, clone it.
        if shouldResetBeforeCloning {
            dependency.gitService.reset()
                .done { _ in
                    self.cloneRemoteRepository()
                }.catch { error in
                    self.notification.onNext(StandardNotification(error: error))
                }
        } else {
            cloneRemoteRepository()
        }

    }

    // MARK: Private helpers

    private func updateLocalRepository() {
        activity.start()
        dependency.gitService.update()
            .done { [weak self] _ in
                self?.isUpdated.onNext(true)
            }.ensure { [weak self] in
                self?.activity.stop()
                self?.isReady.onNext(true)
            }.catch { [weak self] error in
                self?.notification.onNext(StandardNotification(error: error))
            }
    }

    private func cloneRemoteRepository() {
        activity.start()
        dependency.gitService.clone(progressHandler: { progress, _ in
                print(progress)
            })
            .done { [weak self] _ in
                self?.isReady.onNext(true)
            }.ensure { [weak self] in
                    self?.activity.stop()
            }.catch { [weak self] error in
                self?.notification.onNext(StandardNotification(error: error))
            }
    }
}
