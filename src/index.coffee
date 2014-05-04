async = require 'async'
Writable = require('stream').Writable

module.exports = class ParallelWritable extends Writable
  constructor: (options = {}) ->
    @_task = options.task if options.task?
    throw Error "Can't create a ParallelWritable without a task." unless @_task

    @queue = async.queue @_task, options.limit ? 10
    @callbackQueue = []

    # Do highWaterMark buffering in ParallelWritable, not in Writable.
    #
    # Allow Writable to buffer up to 2 items, as it seems to return
    # false on all writes when we give it an internal buffer of 0 or 1,
    # which is undesirable.
    #
    # The default highWaterMark for objectMode streams is 16.
    @highWaterMark = (options.highWaterMark ? 16) - 1
    options.highWaterMark = 2

    options.objectMode = true
    super options

  _write: (chunk, enc, callback) =>
    # If we're all done, process whatever's left in our queue.
    if chunk is null
      if @queue.idle()
        callback null
      else
        # Error handling is taken care of by the callback passed
        # to @queue.push, which will fire before this if there's an error.
        @queue.drain = callback
      return

    @queue.push chunk, (err) =>
      return @emit 'error', err if err
      @callbackQueue.shift().call() if @callbackQueue.length

    # Don't count items that the queue will process on its next tick.
    if @queue.length() - (@queue.concurrency - @queue.running()) < @highWaterMark
      callback()
    else
      @callbackQueue.push callback

  # Wrap end to make sure we clear out whatever's in the queue.
  end: () ->
    @write null, null, (err) =>
      return @emit 'error', err if err
      super()
