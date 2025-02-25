// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Shared
import Storage

protocol LibraryCoordinatorDelegate: AnyObject, LibraryPanelDelegate, RecentlyClosedPanelDelegate {
    func didFinishLibrary(from coordinator: LibraryCoordinator)
}

protocol LibraryNavigationHandler: AnyObject {
    func start(panelType: LibraryPanelType, navigationController: UINavigationController)
    func shareLibraryItem(url: URL, sourceView: UIView)
}

class LibraryCoordinator: BaseCoordinator, LibraryPanelDelegate, LibraryNavigationHandler, ParentCoordinatorDelegate {
    private let profile: Profile
    private let tabManager: TabManager
    private var libraryViewController: LibraryViewController!
    weak var parentCoordinator: LibraryCoordinatorDelegate?
    override var isDismissable: Bool { false }
    private var windowUUID: WindowUUID { return tabManager.windowUUID }

    init(
        router: Router,
        profile: Profile = AppContainer.shared.resolve(),
        tabManager: TabManager
    ) {
        self.profile = profile
        self.tabManager = tabManager
        super.init(router: router)
        initializeLibraryViewController()
    }

    private func initializeLibraryViewController() {
        libraryViewController = LibraryViewController(profile: profile, tabManager: tabManager)
        router.setRootViewController(libraryViewController)
        libraryViewController.childPanelControllers = makeChildPanels()
        libraryViewController.delegate = self
        libraryViewController.navigationHandler = self
    }

    func start(with homepanelSection: Route.HomepanelSection) {
        libraryViewController.setupOpenPanel(panelType: homepanelSection.libraryPanel)
    }

    private func makeChildPanels() -> [UINavigationController] {
        let bookmarksPanel = BookmarksPanel(viewModel: BookmarksPanelViewModel(profile: profile),
                                            windowUUID: windowUUID)
        let historyPanel = HistoryPanel(profile: profile)
        let downloadsPanel = DownloadsPanel()
        let readingListPanel = ReadingListPanel(profile: profile)
        return [
            ThemedNavigationController(rootViewController: bookmarksPanel),
            ThemedNavigationController(rootViewController: historyPanel),
            ThemedNavigationController(rootViewController: downloadsPanel),
            ThemedNavigationController(rootViewController: readingListPanel)
        ]
    }

    // MARK: - LibraryNavigationHandler

    func start(panelType: LibraryPanelType, navigationController: UINavigationController) {
        switch panelType {
        case .bookmarks:
            makeBookmarksCoordinator(navigationController: navigationController)
        case .history:
            makeHistoryCoordinator(navigationController: navigationController)
        case .downloads:
            makeDownloadsCoordinator(navigationController: navigationController)
        case .readingList:
            makeReadingListCoordinator(navigationController: navigationController)
        }
    }

    func shareLibraryItem(url: URL, sourceView: UIView) {
        guard !childCoordinators.contains(where: { $0 is ShareExtensionCoordinator }) else { return }
        let coordinator = makeShareExtensionCoordinator()
        coordinator.start(url: url, sourceView: sourceView)
    }

    private func makeBookmarksCoordinator(navigationController: UINavigationController) {
        guard !childCoordinators.contains(where: { $0 is BookmarksCoordinator }) else { return }
        let router = DefaultRouter(navigationController: navigationController)
        let bookmarksCoordinator = BookmarksCoordinator(
            router: router,
            profile: profile,
            windowUUID: windowUUID,
            parentCoordinator: parentCoordinator,
            navigationHandler: self
        )
        add(child: bookmarksCoordinator)
        (navigationController.topViewController as? BookmarksPanel)?.bookmarkCoordinatorDelegate = bookmarksCoordinator
    }

    private func makeHistoryCoordinator(navigationController: UINavigationController) {
        guard !childCoordinators.contains(where: { $0 is HistoryCoordinator }) else { return }
        let router = DefaultRouter(navigationController: navigationController)
        let historyCoordinator = HistoryCoordinator(
            profile: profile,
            windowUUID: windowUUID,
            router: router,
            parentCoordinator: parentCoordinator,
            navigationHandler: self
        )
        add(child: historyCoordinator)
        (navigationController.topViewController as? HistoryPanel)?.historyCoordinatorDelegate = historyCoordinator
    }

    private func makeDownloadsCoordinator(navigationController: UINavigationController) {
        guard !childCoordinators.contains(where: { $0 is DownloadsCoordinator }) else { return }
        let router = DefaultRouter(navigationController: navigationController)
        let downloadsCoordinator = DownloadsCoordinator(
            router: router,
            profile: profile,
            parentCoordinator: parentCoordinator,
            tabManager: tabManager
        )
        add(child: downloadsCoordinator)
        (navigationController.topViewController as? DownloadsPanel)?.navigationHandler = downloadsCoordinator
    }

    private func makeReadingListCoordinator(navigationController: UINavigationController) {
        guard !childCoordinators.contains(where: { $0 is ReadingListCoordinator }) else { return }
        let router = DefaultRouter(navigationController: navigationController)
        let readingListCoordinator = ReadingListCoordinator(
            parentCoordinator: parentCoordinator,
            navigationHandler: self,
            router: router
        )
        add(child: readingListCoordinator)
        (navigationController.topViewController as? ReadingListPanel)?.navigationHandler = readingListCoordinator
    }

    // MARK: - ParentCoordinatorDelegate

    func didFinish(from childCoordinator: any Coordinator) {
        remove(child: childCoordinator)
    }

    private func makeShareExtensionCoordinator() -> ShareExtensionCoordinator {
        let coordinator = ShareExtensionCoordinator(
            alertContainer: UIView(),
            router: router,
            profile: profile,
            parentCoordinator: self,
            tabManager: tabManager
        )
        add(child: coordinator)
        return coordinator
    }

    // MARK: - LibraryPanelDelegate

    func libraryPanelDidRequestToOpenInNewTab(_ url: URL, isPrivate: Bool) {
        parentCoordinator?.libraryPanelDidRequestToOpenInNewTab(url, isPrivate: isPrivate)
    }

    func libraryPanel(didSelectURL url: URL, visitType: Storage.VisitType) {
        parentCoordinator?.libraryPanel(didSelectURL: url, visitType: visitType)
    }

    func didFinish() {
        parentCoordinator?.didFinishLibrary(from: self)
    }

    var libraryPanelWindowUUID: WindowUUID {
        return windowUUID
    }
}
