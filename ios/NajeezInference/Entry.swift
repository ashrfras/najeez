import Foundation


// Only Runner opens this bundled, signed framework, after its iOS and device
// checks. The rest of the app retains its original deployment target.
@_cdecl("najeez_qwen_review")
public func review(_ raw: UnsafeRawPointer) -> UnsafeMutableRawPointer {
  let input = Unmanaged<NSDictionary>.fromOpaque(raw).takeUnretainedValue()
  let response: NSDictionary
  #if targetEnvironment(simulator)
  response = ["error": "unsupported"]
  #else
  do {
    guard let path = input["path"] as? String, let data = input["data"] as? String,
          let cancellation = input["cancel"] as? Progress else { throw QwenError.inference }
    let text = try QwenEngine.review(file: URL(fileURLWithPath: path), evidence: data, cancellation: cancellation)
    response = ["text": text]
  } catch {
    response = ["error": (error as? QwenError)?.rawValue ?? "inference"]
  }
  #endif
  return Unmanaged.passRetained(response).toOpaque()
}
