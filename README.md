# GBLoading ![Version](https://img.shields.io/cocoapods/v/GBLoading.svg?style=flat)&nbsp;![License](https://img.shields.io/badge/license-Apache_2-green.svg?style=flat)

An elegant, lightweight & most importantly robust asynchronous resource loading library for iOS.

Basic Usage
------------

To asynchornously load a resource simply call (your success and failure handlers will be called on the main thread):

```objective-c    
[[GBLoading sharedLoading] loadResource:@"http://..." withSuccess:^(id object) {
    //do something with loaded object
} failure:^(BOOL isCancelled) {
    NSLog(@"failed to load");
}];
```

That's it. You can call whatever `UIKit` methods you want in your handler because your block is called on the main thread, even though the resource was loaded on a background thread.


Don't forget to import static library header (on iOS):

```objective-c
#import "GBLoading.h"
```

Advanced Usage
------------

You can associate as many handlers with a resource load as you want, so if you call the above many times for the same resource, but with different handlers, all your handlers will fire once the resource becomes available, in the order they were called, and the data will be dowloaded only once!

If the resource that comes from the network needs some heavy processing, then you can do that on the background thread as well before being called back on the main thread in your handler. You can do this by providing a block that processes the raw data that came from the network.

```objective-c 
[[GBLoading sharedLoading] loadResource:@"http://..." withBackgroundProcessor:^id(NSData *rawData) {
    return [UIImage imageWithData:rawData];
} success:^(id object) {
    UIImage *loadedImage = (UIImage *)object;
    someImageView.image = loadedImage;
    //do something with loaded image
} failure:^(BOOL isCancelled) {
    NSLog(@"failed to load");
}];
```

As with above, the processing will only happen once after the initial load of the network, keeping your app nice and snappy. If you need to always reprocess, just put that logic in the success handler.
    
If you need to cancel a load call this:

```objective-c 
[[GBLoading sharedLoading] cancelLoadForResource:@"http://"];
```

However be aware that this will cancel all handlers for that particular load (if you have several).

If you want to cancel 1 specific load, then you should provide a `GBLoadingCanceller` pointer to `GBLoading`. `GBLoadingCanceller` is a very simple object with just 1 method: `-[GBLoadingCanceller cancelLoad]`. You would use this to cancel a very specific load, e.g. when a `UITableViewCell` goes off screen (in this case you never want to cancel all loads, because another cell might have requested the same resource).

```objective-c
GBLoadingCanceller *canceller;

[[GBLoading sharedLoading] loadResource:@"http://..." withBackgroundProcessor:^id(id inputObject) {
    return [UIImage imageWithData:inputObject];
} success:^(id object) {
    UIImage *loadedImage = (UIImage *)object;
    //do something with loaded image
} failure:^(BOOL isCancelled) {
    NSLog(@"failed to load");
} canceller:&canceller];
```

And then to do the actual cancel, you'd call:

```objective-c
//...some time later, e.g. when your UITableViewCell goes of screen
[canceller cancel];
```

Personally, I like to set the `canceller` object as an associated object on my `UITableViewCell` inside `-[UITableView cellForRowAtIndexPath:]`, this way it goes wherever the cell goes. And then inside `-[UITableView tableView:didEndDisplayingCell:forRowAtIndexPath:]` (or inside `-[UITableViewCell prepareForReuse]`), I retrieve the associated object from the cell and call `cancel` on it. It's very robust, and most importantly super simple; it precludes you from having to tracking in flight operations in your own data structures, which cells which specific load operation is associated to, and the general nightmare related to the async loading of resources for tables. You could just add a property for the canceller to your specific `UITableViewCell` subclass if you don't like the idea of messing with the runtime. The canceller object is about as light as it can get: 1 method implementation and 1 private object reference, so they don't add much weight to your cells at all.

If you receive a memory warning, or if for any other reason you want to clear the cache, then you can do so, however if you then request the same resource again (it will have to be re-downloaded and re-processed):

```objective-c
[[GBLoading sharedLoading] clearCache];
```

If you need finer grained control over cache, you can remove specific resources:

```objective-c
[[GBLoading sharedLoading] removeResourceFromCache:@"http://"];
```

If for any reason you want to create your own instances of GBLoading, it's perfectly safe to do so. They won't interfere with each other:

```objective-c
GBLoading *anotherInstance = [GBLoading new];
```

Dependencies
------------

* [GBStorage](https://github.com/lmirosevic/GBStorage)

Runs on iOS 5 and higher.

Copyright & License
------------

Copyright 2013 Luka Mirosevic

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License in the LICENSE file, or at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
