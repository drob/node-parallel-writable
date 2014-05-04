stream-parallel
=========

Create writable streams that process items in parallel.

## Examples

Creating a parallel writable stream by passing in a task:
```javascript
var task = function (item, callback) {
  console.log('Processing item: ', item);
  callback();
}

var writable = new ParallelWritable({task: task, limit: 10});
var readable = getReadableStreamSomehow();

readable.on('error', function (err) { console.log('Error!!', err); });
writable
  .on('error', function (err) { console.log('Error!!', err); });
  .on('finish', function() { console.log('All done!'); });
readable.pipe(writable);
```

Alternately, you can create a parallel writable stream by subclassing the `ParallelWritable` class and supplying a `_task`
function, e.g.:
```javascript
function FileDeleter(options) {
  ParallelWritable.call(this, options);
}

util.inherits(FileDeleter, ParallelWritable);

FileDeleter.prototype._task = function(filename, callback) {
  fs.unlink(filename, callback);
}
```

If we pass in an `options` hash with `limit` set to `5`, this will create a writable stream that deletes up to five files in parallel. If one of those `fs.unlink` calls hangs, we'll still make progress with the other four concurrent deletions.

## Usage

#### new ParallelWritable(options)

In addition to the standard writable stream options, `ParallelWritable` supports:
* `task(item, callback)` - function to be run on each object written to this stream. This function must call `callback`, with an optional error, when it is done.
* `limit` - maximum number of concurrent calls to `task(item, callback)`. Defaults to `10`.
