//
//
//  Kin.swift
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//
//  kinecosystem.org
//

import Foundation
import KinSDK
import KinUtil

enum KinEcosystemError: Error {
    case kinNotStarted
}

public class Kin {
    
    public static let shared = Kin()
    fileprivate(set) var core: Core?
    
    fileprivate init() { }
    
    @discardableResult
    public func start(apiKey: String, userId: String, appId: String, jwt: String? = nil, networkId: NetworkId = .testNet) -> Bool {
        guard core == nil else { return true }
        guard   let modelPath = Bundle.ecosystem.path(forResource: "KinEcosystem",
                                                      ofType: "momd"),
                let store = try? EcosystemData(modelName: "KinEcosystem",
                                               modelURL: URL(string: modelPath)!),
                let chain = try? Blockchain(networkId: networkId) else {
            // TODO: Analytics + no start
            logError("start failed")
            return false
        }
        var url: URL
        switch networkId {
        case .mainNet:
            url = URL(string: "http://api.kinmarketplace.com/v1")!
        default:
            url = URL(string: "http://localhost:3000/v1")!
        }
        let network = EcosystemNet(config: EcosystemConfiguration(baseURL: url,
                                                                  apiKey: apiKey,
                                                                  appId: appId,
                                                                  userId: userId,
                                                                  jwt: jwt,
                                                                  publicAddress: chain.account.publicAddress))
        core = Core(network: network, data: store, blockchain: chain)
        // TODO: move this to dev initiated (not on start)
        updateData(with: OffersList.self, from: "offers").then {
            self.updateData(with: OrdersList.self, from: "orders")
            }.error { error in
                logError("data sync failed")
        }
        return true
    }
    
    public func balance(_ completion: @escaping (Decimal) -> ()) {
        guard let core = core else {
            logError("Kin not started")
            return
        }
        core.blockchain.balance().then(on: DispatchQueue.main) { balance in
            completion(balance)
            }.error { error in
                logWarn("returning zero for balance because real balance retreive failed, error: \(error)")
                completion(0)
        }
    }
    
    public func launchMarketplace(from parentViewController: UIViewController) {
        guard let core = core else {
            logError("Kin not started")
            return
        }
        
//        let mpViewController = MarketplaceViewController(nibName: "MarketplaceViewController", bundle: Bundle.ecosystem)
//        mpViewController.core = core
//        let navigationController = KinNavigationViewController(nibName: "KinNavigationViewController",
//                                                                bundle: Bundle.ecosystem,
//                                                                rootViewController: mpViewController)
//        navigationController.core = core
//        parentViewController.present(navigationController, animated: true)
        
        
        // TODO: check here if blockcahin is onboarded and decide if welcome or marketplace
        let welcomeVC = WelcomeViewController(nibName: "WelcomeViewController", bundle: Bundle.ecosystem)
        welcomeVC.core = core
        parentViewController.present(welcomeVC, animated: true)
    }
    
    func updateData<T: EntityPresentor>(with dataPresentorType: T.Type, from path: String) -> Promise<Void> {
        guard let core = core else {
            logError("Kin not started")
            return Promise<Void>().signal(KinEcosystemError.kinNotStarted)
        }
        return core.network.getDataAtPath(path).then { data in
            self.core!.data.sync(dataPresentorType, with: data)
        }
    }
    
    
}
