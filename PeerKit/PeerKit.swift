//
//  PeerKit.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/5/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import MultipeerConnectivity

// MARK: Type Aliases

public typealias PeerBlock = ((myPeerID: MCPeerID, peerID: MCPeerID) -> Void)
public typealias EventBlock = ((peerID: MCPeerID, event: String, object: AnyObject?) -> Void)
public typealias ObjectBlock = ((peerID: MCPeerID, object: AnyObject?) -> Void)
public typealias ResourceBlock = ((myPeerID: MCPeerID, resourceName: String, peer: MCPeerID, localURL: URL) -> Void)

// MARK: Event Blocks

public var onConnecting: PeerBlock?
public var onConnect: PeerBlock?
public var onDisconnect: PeerBlock?
public var onEvent: EventBlock?
public var onEventObject: ObjectBlock?
public var onFinishReceivingResource: ResourceBlock?
public var eventBlocks = [String: ObjectBlock]()

// MARK: PeerKit Globals

#if os(iOS)
import UIKit
public let myName = UIDevice.current().name
#else
public let myName = Host.current().localizedName ?? ""
#endif

public var transceiver = Transceiver(displayName: myName)
public var session: MCSession?

// MARK: Event Handling

func didConnecting(_ myPeerID: MCPeerID, peer: MCPeerID) {
    if let onConnecting = onConnecting {
        DispatchQueue.main.async(execute: {
            onConnecting(myPeerID: myPeerID, peerID: peer)
        })
    }
}

func didConnect(_ myPeerID: MCPeerID, peer: MCPeerID) {
    if session == nil {
        session = transceiver.session.mcSession
    }
    if let onConnect = onConnect {
        DispatchQueue.main.async(execute: {
            onConnect(myPeerID: myPeerID, peerID: peer)
        })
    }
}

func didDisconnect(_ myPeerID: MCPeerID, peer: MCPeerID) {
    if let onDisconnect = onDisconnect {
        DispatchQueue.main.async(execute: {
            onDisconnect(myPeerID: myPeerID, peerID: peer)
        })
    }
}

func didReceiveData(_ data: Data, fromPeer peer: MCPeerID) {
    if let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: AnyObject],
        let event = dict["event"] as? String,
        let object: AnyObject? = dict["object"] {
            DispatchQueue.main.async(execute: {
                if let onEvent = onEvent {
                    onEvent(peerID: peer, event: event, object: object)
                }
                if let eventBlock = eventBlocks[event] {
                    eventBlock(peerID: peer, object: object)
                }
            })
    }
}

func didFinishReceivingResource(_ myPeerID: MCPeerID, resourceName: String, fromPeer peer: MCPeerID, atURL localURL: URL) {
    if let onFinishReceivingResource = onFinishReceivingResource {
        DispatchQueue.main.async(execute: {
            onFinishReceivingResource(myPeerID: myPeerID, resourceName: resourceName, peer: peer, localURL: localURL)
        })
    }
}

// MARK: Advertise/Browse

public func transceive(_ serviceType: String, discoveryInfo: [String: String]? = nil) {
    transceiver.startTransceiving(serviceType, discoveryInfo: discoveryInfo)
}

public func advertise(_ serviceType: String, discoveryInfo: [String: String]? = nil) {
    transceiver.startAdvertising(serviceType, discoveryInfo: discoveryInfo)
}

public func browse(_ serviceType: String) {
    transceiver.startBrowsing(serviceType)
}

public func stopTransceiving() {
    transceiver.stopTransceiving()
    session = nil
}

// MARK: Events

public func sendEvent(_ event: String, object: AnyObject? = nil, toPeers peers: [MCPeerID]? = session?.connectedPeers) {
    guard let peers = peers , !peers.isEmpty else {
        return
    }

    var rootObject: [String: AnyObject] = ["event": event]

    if let object: AnyObject = object {
        rootObject["object"] = object
    }

    let data = NSKeyedArchiver.archivedData(withRootObject: rootObject)

    do {
        try session?.send(data, toPeers: peers, with: .reliable)
    } catch _ {
    }
}

public func sendResourceAtURL(_ resourceURL: URL, withName resourceName: String, toPeers peers: [MCPeerID]? = session?.connectedPeers,
                              withCompletionHandler completionHandler: ((NSError?) -> Void)?) -> [Progress?]? {
    if let session = session {
        return peers?.map { peerID in
            return session.sendResource(at: resourceURL, withName: resourceName, toPeer: peerID, withCompletionHandler: completionHandler)
        }
    }
    return nil
}
