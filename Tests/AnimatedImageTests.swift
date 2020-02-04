import XCTest
import SwiftUI
import ViewInspector
@testable import SDWebImageSwiftUI

extension AnimatedImage : Inspectable {}

extension AnimatedImage {
    struct WrapperView: View & Inspectable {
        var name: String
        var bundle: Bundle?
        @State var isAnimating: Bool

        var onViewUpdate: (Self, PlatformView, AnimatedImage.Context) -> Void

        var body: some View {
            AnimatedImage(name: name, bundle: bundle, isAnimating: $isAnimating)
            .onViewUpdate { view, context in
                self.onViewUpdate(self, view, context)
            }
        }
    }
}

class AnimatedImageTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAnimatedImageWithName() throws {
        let expectation = self.expectation(description: "AnimatedImage name initializer")
        let imageName = "TestImage.gif"
        let imageView = AnimatedImage(name: imageName, bundle: TestUtils.testImageBundle())
        ViewHosting.host(view: imageView)
        let animatedImageView = try imageView.inspect().actualView().platformView().wrapped
        if let animatedImage = animatedImageView.image as? SDAnimatedImage {
            XCTAssertEqual(animatedImage.animatedImageLoopCount, 0)
            XCTAssertEqual(animatedImage.animatedImageFrameCount, 5)
        } else {
            XCTFail("SDAnimatedImageView.image invalid")
        }
        XCTAssertEqual(animatedImageView.sd_imageName, imageName)
        expectation.fulfill()
        self.waitForExpectations(timeout: 5, handler: nil)
        ViewHosting.expel()
    }
    
    func testAnimatedImageWithData() throws {
        let expectation = self.expectation(description: "AnimatedImage data initializer")
        let imageData = try XCTUnwrap(TestUtils.testImageData(name: "TestImageAnimated.apng"))
        let imageView = AnimatedImage(data: imageData)
        ViewHosting.host(view: imageView)
        let animatedImageView = try imageView.inspect().actualView().platformView().wrapped
        if let animatedImage = animatedImageView.image as? SDAnimatedImage {
            XCTAssertEqual(animatedImage.animatedImageLoopCount, 0)
            XCTAssertEqual(animatedImage.animatedImageFrameCount, 101)
        } else {
            XCTFail("SDAnimatedImageView.image invalid")
        }
        XCTAssertEqual(animatedImageView.sd_imageData, imageData)
        expectation.fulfill()
        self.waitForExpectations(timeout: 5, handler: nil)
        ViewHosting.expel()
    }
    
    func testAnimatedImageWithURL() throws {
        let expectation = self.expectation(description: "AnimatedImage url initializer")
        let imageUrl = URL(string: "https://raw.githubusercontent.com/liyong03/YLGIFImage/master/YLGIFImageDemo/YLGIFImageDemo/joy.gif")
        let imageView = AnimatedImage(url: imageUrl)
        .onSuccess { image, cacheType in
            if let animatedImage = image as? SDAnimatedImage {
                XCTAssertEqual(animatedImage.animatedImageLoopCount, 0)
                XCTAssertEqual(animatedImage.animatedImageFrameCount, 389)
            } else {
                XCTFail("SDAnimatedImageView.image invalid")
            }
            expectation.fulfill()
        }.onFailure { error in
            XCTFail(error.localizedDescription)
        }
        ViewHosting.host(view: imageView)
        let animatedImageView = try imageView.inspect().actualView().platformView().wrapped
        XCTAssertEqual(animatedImageView.sd_imageURL, imageUrl)
        self.waitForExpectations(timeout: 5, handler: nil)
        ViewHosting.expel()
    }
    
    func testAnimatedImageBinding() throws {
        let expectation = self.expectation(description: "AnimatedImage binding control")
        var viewUpdateCount = 0
        // Use wrapper to make the @Binding works
        let wrapperView = AnimatedImage.WrapperView(name: "TestLoopCount.gif", bundle: TestUtils.testImageBundle(), isAnimating: true) { wrapperView, view, context in
            viewUpdateCount += 1
            guard let animatedImageView = view as? SDAnimatedImageView else {
                XCTFail("AnimatedImage's view should be SDAnimatedImageView")
                return
            }
            if let animatedImage = animatedImageView.image as? SDAnimatedImage {
                XCTAssertEqual(animatedImage.animatedImageLoopCount, 1)
                XCTAssertEqual(animatedImage.animatedImageFrameCount, 2)
            } else {
                XCTFail("AnimatedImage's image should be SDAnimatedImage")
            }
            // View update times before stable from SwiftUI, different behavior for AppKit/UIKit
            #if os(macOS)
            let stableViewUpdateCount = 1
            #else
            let stableViewUpdateCount = 2
            #endif
            switch viewUpdateCount {
            case stableViewUpdateCount:
                // #1 SwiftUI's own updateUIView call
                #if os(iOS) || os(tvOS)
                XCTAssertTrue(animatedImageView.isAnimating)
                #else
                XCTAssertTrue(animatedImageView.animates)
                #endif
                DispatchQueue.main.async {
                    wrapperView.isAnimating = false
                }
            case stableViewUpdateCount + 1:
                // #3 AnimatedImage's isAnimating @Binding trigger update (from above)
                #if os(iOS) || os(tvOS)
                XCTAssertFalse(animatedImageView.isAnimating)
                #else
                XCTAssertFalse(animatedImageView.animates)
                #endif
                expectation.fulfill()
            default: break
                // do not care
            }
        }
        ViewHosting.host(view: wrapperView)
        self.waitForExpectations(timeout: 5, handler: nil)
        ViewHosting.expel()
    }
    
    func testAnimatedImageModifier() throws {
        let expectation = self.expectation(description: "WebImage modifier")
        let imageUrl = URL(string: "https://assets.sbnation.com/assets/2512203/dogflops.gif")
        let imageView = AnimatedImage(url: imageUrl, options: [.progressiveLoad], context: [.imageScaleFactor: 1])
        let introspectView = imageView
        .onSuccess { _, _ in
            expectation.fulfill()
        }
        .onFailure { _ in
            XCTFail()
        }
        .onProgress { _, _ in
            
        }
        .onViewCreate { view, context in
            XCTAssert(view.isKind(of: SDAnimatedImageView.self))
            context.coordinator.userInfo = ["foo" : "bar"]
        }
        .onViewUpdate { view, context in
            XCTAssert(view.isKind(of: SDAnimatedImageView.self))
            XCTAssertEqual(context.coordinator.userInfo?["foo"] as? String, "bar")
        }
        .placeholder(PlatformImage())
        .indicator(SDWebImageActivityIndicator.medium)
        // Image
        .resizable()
        .renderingMode(.original)
        .interpolation(.high)
        .antialiased(true)
        // Animation
        .runLoopMode(.common)
        .customLoopCount(1)
        .maxBufferSize(0)
        .pausable(true)
        .purgeable(true)
        .playbackRate(1)
        .transition(.fade)
        .animation(.easeInOut)
        _ = try introspectView.inspect()
        ViewHosting.host(view: introspectView)
        self.waitForExpectations(timeout: 5, handler: nil)
        ViewHosting.expel()
    }
}
