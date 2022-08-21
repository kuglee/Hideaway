import Foundation

public struct DefaultDistributedNotificationCenter {
  public var post: (NSNotification.Name, String?) -> Void
  public var observe: (NSNotification.Name, @escaping @Sendable (Notification) -> Void) -> Void
}

extension DefaultDistributedNotificationCenter {
  public static var live: Self {
    .init(
      post: { name, object in
        DistributedNotificationCenter.default().post(name: name, object: object)
      },
      observe: { name, callback in
        DistributedNotificationCenter.default()
          .addObserver(forName: name, object: nil, queue: nil, using: callback)
      }
    )
  }
}
