//
//  DocumentViewController.swift
//  Textor
//
//  Created by Louis D'hauwe on 31/12/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import UIKit
import StoreKit

var hasAskedForReview = false

var documentsClosed = 0

class DocumentViewController: UIViewController {

	@IBOutlet weak var textView: UITextView!
    @IBOutlet var workingCopyStatusButton: UIBarButtonItem!
    
	var document: Document?

	private let keyboardObserver = KeyboardObserver()

	override func viewDidLoad() {
		super.viewDidLoad()
		
		textView.delegate = self
		
		self.navigationController?.view.tintColor = .appTintColor
		self.view.tintColor = .appTintColor
		
		updateTheme()

		textView.alwaysBounceVertical = true
		
		keyboardObserver.observe { [weak self] (state) in
			
			guard let textView = self?.textView else {
				return
			}
			
			guard let `self` = self else {
				return
			}
			
			let rect = textView.convert(state.keyboardFrameEnd, from: nil).intersection(textView.bounds)
			
			UIView.animate(withDuration: state.duration, delay: 0.0, options: state.options, animations: {
				
				textView.contentInset.bottom = rect.height - self.view.safeAreaInsets.bottom
				textView.scrollIndicatorInsets.bottom = rect.height - self.view.safeAreaInsets.bottom
				
			}, completion: nil)
			
		}
		
		textView.text = ""
		
		document?.open(completionHandler: { [weak self] (success) in
			
			guard let `self` = self else {
				return
			}
			
			if success {
				
				self.textView.text = self.document?.text
				
				// Calculate layout for full document, so scrolling is smooth.
				self.textView.layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: self.textView.text.count))
				
				if self.textView.text.isEmpty {
					self.textView.becomeFirstResponder()
				}
				
				self.loadWorkingCopyStatus()
				
			} else {
				
				self.showAlert("Error", message: "Document could not be opened.", dismissCallback: {
					self.dismiss(animated: true, completion: nil)
				})
				
			}
			
		})
		
	}
	
	@objc private func update() {
		guard unwrittenChanges else { return }
		unwrittenChanges = false
		
		flushTextToDocument()
		document?.autosave(completionHandler: { success in
			self.loadWorkingCopyStatus()
		})
	}
	
	private var unwrittenChanges = false
	private func scheduleUpdate() {
		unwrittenChanges = true
		NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(update), object: nil)
		perform(#selector(update), with: nil, afterDelay: 1)
	}
	
	private func updateTheme() {
		
		let font = UserDefaultsController.shared.font
		let fontSize = UserDefaultsController.shared.fontSize
		textView.font = UIFont(name: font, size: fontSize)
		
		if UserDefaultsController.shared.isDarkMode {
			textView.textColor = .white
			textView.backgroundColor = .darkBackgroundColor
			textView.keyboardAppearance = .dark
			textView.indicatorStyle = .white
			navigationController?.navigationBar.barStyle = .blackTranslucent
		} else {
			textView.textColor = .black
			textView.backgroundColor = .white
			textView.keyboardAppearance = .default
		}
		
		self.view.backgroundColor = textView.backgroundColor
		
	}
	
	private var urlService: WorkingCopyUrlService?
	
	@IBAction func workingCopyStatusTapped(_ sender: Any) {
		guard let service = urlService else { return }
		service.determineCommitLink({
			(url, error) in
			
			if let error = error {
				self.showErrorAlert(error)
			}
			
			if let url = url {
				UIApplication.shared.open(url)
			}
		})
	}
	
	private func loadWorkingCopyStatus() {
		guard let url = document?.fileURL else { return }
		
		// try to use existing service instance
		if let service = urlService {
			loadStatusWithService(service)
			return
		}
		
		// Try to get file provider service
		WorkingCopyUrlService.getFor(url, completionHandler: { (service, error) in
			// the service might very well be missing if you are picking from some other
			// Location than Working Copy or the version of Working Copy isn't new enough
			guard let service = service else { return }
			self.urlService = service
			
			self.loadStatusWithService(service)
		})
	}
	
	private func loadStatusWithService(_ service: WorkingCopyUrlService) {
		service.loadChangeText({ title in
			
			guard let button = self.workingCopyStatusButton else { return }
			button.title = title
			button.isEnabled = !title.isEmpty
		})
	}
	
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)


    }

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		documentsClosed += 1

		if !hasAskedForReview && documentsClosed >= 4 {
			hasAskedForReview = true
			SKStoreReviewController.requestReview()
		}

	}

	@IBAction func shareDocument(_ sender: UIBarButtonItem) {

		guard let url = document?.fileURL else {
			return
		}

		textView.resignFirstResponder()
		
		var activityItems: [Any] = [url]

		if UIPrintInteractionController.isPrintingAvailable {
			
			let printFormatter = UISimpleTextPrintFormatter(text: self.textView.text ?? "")
			let printRenderer = UIPrintPageRenderer()
			printRenderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
			activityItems.append(printRenderer)
		}

		let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)

		activityVC.popoverPresentationController?.barButtonItem = sender

		self.present(activityVC, animated: true, completion: nil)
	}
	
	private func flushTextToDocument() {
		let currentText = self.document?.text ?? ""
		
		self.document?.text = self.textView.text
		
		if currentText != self.textView.text {
			self.document?.updateChangeCount(.done)
		}
	}

    @IBAction func dismissDocumentViewController() {

		flushTextToDocument()
		
        dismiss(animated: true) {
            self.document?.close(completionHandler: nil)
        }
    }

}

extension DocumentViewController: UITextViewDelegate {
	
	func textViewDidEndEditing(_ textView: UITextView) {
		
		let currentText = self.document?.text ?? ""
		
		self.document?.text = self.textView.text
		
		if currentText != self.textView.text {
			self.document?.updateChangeCount(.done)
		}

	}
	
	func textViewDidChange(_ textView: UITextView) {
		if urlService != nil {
			scheduleUpdate()
		}
	}
	
}

extension DocumentViewController: StoryboardIdentifiable {
	
	static var storyboardIdentifier: String {
		return "DocumentViewController"
	}
	
}
