_ = require 'underscore'
assert = require 'assert'
async = require 'async'
ParallelWritable = require '../'

describe 'ParallelWritable', () ->
  this.timeout 5000

  getParallelWritable = (options) ->
    numRunning = 0
    maxConcurrency = 0
    numProcessed = 0
    task = (item, callback) ->
      # Keep track of how many are running and wait
      # a nontrivial amount of time before returning.
      numRunning++
      maxConcurrency = Math.max numRunning, maxConcurrency
      setTimeout () ->
        numRunning--
        numProcessed++
        callback()
      , 500
    stream = new ParallelWritable _(options).extend({task})
    stream.on 'finish', () ->
      stats = {maxConcurrency, numProcessed}
      stream.emit 'stats', stats

  it 'should process items in parallel', (done) ->
    parallelWritable = getParallelWritable {limit: 3}
    _(10).times (num) ->
      parallelWritable.write num
    parallelWritable.end()

    parallelWritable.on 'error', done
    parallelWritable.on 'stats', (stats) ->
      {maxConcurrency, numProcessed} = stats
      assert.equal maxConcurrency, 3
      assert.equal numProcessed, 10
      done()

  it 'should process all the times when fewer than the concurrency limit are sent', (done) ->
    parallelWritable = getParallelWritable {limit: 10}
    _(7).times (num) ->
      parallelWritable.write num
    parallelWritable.end()

    parallelWritable.on 'error', done
    parallelWritable.on 'stats', (stats) ->
      {maxConcurrency, numProcessed} = stats
      assert.equal maxConcurrency, 7
      assert.equal numProcessed, 7
      done()

  # In order for backpressure to work, writable.write() needs to return false
  # when we're buffering above highWaterMark items.
  it 'should send backpressure correctly', (done) ->
    parallelWritable = getParallelWritable {limit: 4, highWaterMark: 5}

    # We should be able to store 8 objects without returning false, as this is
    # one less than the number of items we can process at once (4) and the number
    # we're allowed to buffer (5).
    _(8).times (num) ->
      belowHighWaterMark = parallelWritable.write num
      assert belowHighWaterMark, 'ParallelWritable should keep requesting the next item when its buffer is below hwm'

    _(5).times (num) ->
      belowHighWaterMark = parallelWritable.write num
      assert not belowHighWaterMark, 'ParallelWritable should send backpressure when its buffer is full'

    parallelWritable.end()

    parallelWritable.on 'error', done
    parallelWritable.on 'stats', (stats) ->
      {maxConcurrency, numProcessed} = stats
      assert.equal maxConcurrency, 4
      assert.equal numProcessed, 13
      done()

  it 'works correctly with subclassing instead of a passed in task', (done) ->
    Subclass = class Subclass extends ParallelWritable
      constructor: (options) ->
        @numRunning = 0
        @maxConcurrency = 0
        @numProcessed = 0
        super options

      _task: (item, callback) =>
        @numRunning++
        @maxConcurrency = Math.max @numRunning, @maxConcurrency
        setImmediate () =>
          @numRunning--
          @numProcessed++
          callback()

    stream = new Subclass {limit: 3}
    stream.on 'finish', () ->
      stats = {@maxConcurrency, @numProcessed}
      @emit 'stats', stats

    _(10).times (num) ->
      stream.write(num)
    stream.end()

    stream.on 'error', done
    stream.on 'stats', (stats) ->
      {maxConcurrency, numProcessed} = stats
      assert.equal maxConcurrency, 3
      assert.equal numProcessed, 10
      done()
