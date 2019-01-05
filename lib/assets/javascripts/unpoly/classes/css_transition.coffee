u = up.util
e = up.element

class up.CssTransition

  constructor: (@element, @lastFrameKebab, options) ->
    @lastFrameKeysKebab = Object.keys(@lastFrameKebab)
    if u.some(@lastFrameKeysKebab, (key) -> key.match(/A-Z/))
      up.fail('Animation keys must be kebab-case')
    @finishEvent = options.finishEvent
    @duration = options.duration
    @delay = options.delay
    @totalDuration = @delay + @duration
    @easing = options.easing
    @finished = false

  start: =>
    if @lastFrameKeysKebab.length == 0
      @finished = true
      # If we have nothing to animate, we will never get a transitionEnd event
      # and the returned promise will never resolve.
      return Promise.resolve()

    @deferred = u.newDeferred()
    @pauseOldTransition()
    @startTime = new Date()
    @startFallbackTimer()
    @listenToFinishEvent()
    @listenToTransitionEnd()

    @startMotion()

    return @deferred.promise()

  listenToFinishEvent: =>
    if @finishEvent
      @element.addEventListener(@finishEvent, @onFinishEvent)

  stopListenToFinishEvent: =>
    if @finishEvent
      @element.removeEventListener(@finishEvent, @onFinishEvent)

  onFinishEvent: (event) =>
    # don't waste time letting the event bubble up the DOM
    event.stopPropagation()
    @finish()

  startFallbackTimer: =>
    timingTolerance = 100
    @fallbackTimer = u.setTimer (@totalDuration + timingTolerance), =>
      @finish()

  stopFallbackTimer: =>
    clearTimeout(@fallbackTimer)

  listenToTransitionEnd: =>
    @element.addEventListener 'transitionend', @onTransitionEnd

  stopListenToTransitionEnd: =>
    @element.removeEventListener 'transitionend', @onTransitionEnd

  onTransitionEnd: (event) =>
    # Check if the transitionend event was caused by our own transition,
    # and not by some other transition that happens to affect this element.
    return unless event.target == @element

    # Check if we are receiving a late transitionEnd event
    # from a previous CSS transition.
    elapsed = new Date() - @startTime
    return unless elapsed > 0.25 * @totalDuration

    completedPropertyKebab = event.propertyName
    return unless u.contains(@lastFrameKeysKebab, completedPropertyKebab)

    @finish()

  finish: =>
    # Make sure that any queued events won't finish multiple times.
    return if @finished
    @finished = true

    @stopFallbackTimer()
    @stopListenToFinishEvent()
    @stopListenToTransitionEnd()

    # Cleanly finish our own transition so the old transition
    # (or any other transition set right after that) will be able to take effect.
    e.concludeCssTransition(@element)

    @resumeOldTransition()

    @deferred.resolve()

  pauseOldTransition: =>
    oldTransition = e.style(@element, [
      'transitionProperty',
      'transitionDuration',
      'transitionDelay',
      'transitionTimingFunction'
    ])

    if e.hasCssTransition(oldTransition)
      # Freeze the previous transition at its current place, by setting the currently computed,
      # animated CSS properties as inline styles. Transitions on all properties will not be frozen,
      # since that would involve setting every single CSS property as an inline style.
      unless oldTransition.transitionProperty == 'all'
        oldTransitionProperties = oldTransition.transitionProperty.split(/\s*,\s*/)
        oldTransitionFrameKebab = e.style(@element, oldTransitionProperties)
        @setOldTransitionTargetFrame = e.setTemporaryStyle(@element, oldTransitionFrameKebab)

      # Stop the existing CSS transition so it does not emit transitionEnd events
      @setOldTransition = e.concludeCssTransition(@element)

  resumeOldTransition: =>
    @setOldTransitionTargetFrame?()
    @setOldTransition?()

  startMotion: =>
    e.setStyle @element,
      transitionProperty: Object.keys(@lastFrameKebab).join(', ')
      transitionDuration: "#{@duration}ms"
      transitionDelay: "#{@delay}ms"
      transitionTimingFunction: @easing
    e.setStyle(@element, @lastFrameKebab)

