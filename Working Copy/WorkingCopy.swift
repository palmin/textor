//
//  WorkingCopy.swift
//  Textor
//
//  Created by Anders Borum on 21/09/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation

extension WorkingCopyUrlService {
	
	// determine status of file covered by URL service producing results on the form
	//     ""        error checking status or current file
	//     "+3"      3 lines added
	//     "-2"      2 lines deleted
	//     "-2+3"    2 lines deleted and 3 added
	//     "binary"  non-text file modified
	public func loadChangeText(_ completion: @escaping (String) -> ()) {
		fetchStatus(completionHandler: {
			(linesAdded, linesDeleted, error) in
			
			if error != nil {
				completion("")
				return
			}
			
			switch (linesAdded, linesDeleted) {
			
				case (UInt(NSNotFound), _):
					completion("binary")
				
				case (0,0):
					completion("") // file is current
				
				case (0, _):
					completion("-\(linesDeleted)")
				
				case (_, 0):
					completion("+\(linesAdded)")
				
				default:
				// modified text file
					completion("-\(linesDeleted)+\(linesAdded)")
			}
		})
	}
	
	public func determineCommitLink(_ completion: @escaping (URL?, Error?) -> ()) {
		
		// request deep link
		determineDeepLink(completionHandler: { (url, error) in
	
			var callbackUrl: URL?
			defer {
				completion(callbackUrl, error)
			}
			
			guard let url = url else { return }
			
			// we escape everything outside urlQueryAllowed but also & that starts next url parameter
			let allowChars = CharacterSet.urlQueryAllowed.intersection(CharacterSet(charactersIn: "&").inverted)
			
			guard let escaped = url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowChars) else { return }
			callbackUrl = URL(string: "working-copy://x-callback-url/commit?url=\(escaped)&x-cancel=textor://&x-success=textor://")
		})
	}
}
