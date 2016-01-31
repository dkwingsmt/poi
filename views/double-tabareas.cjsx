path = require 'path-extra'
glob = require 'glob'
Promise = require 'bluebird'
__ = i18n.others.__.bind(i18n.others)
__n = i18n.others.__n.bind(i18n.others)
semver = require 'semver'
fs = require 'fs-extra'
{_, $, React, ReactBootstrap, FontAwesome} = window
{Nav, NavItem, NavDropdown, MenuItem} = ReactBootstrap
async = Promise.coroutine
classnames = require 'classnames'

$('poi-main').className += 'double-tabbed'
window.doubleTabbed = true

PluginWrap = React.createClass
  shouldComponentUpdate: (nextProps, nextState)->
    false
  render: ->
    React.createElement @props.plugin.reactClass

settings = require path.join(ROOT, 'views', 'components', 'settings')
mainview = require path.join(ROOT, 'views', 'components', 'main')

TabContentsUnion = React.createClass
  getInitialState: ->
    nowKey: null

  setNewKey: (key) ->
    @setState
      nowKey: key
    @props.onNewKey? key

  handleTabShow: (e) ->
    key = e.detail.key
    React.Children.forEach @props.children, (child) =>
      if child.key == key
        @setNewKey key

  activeKey: ->
    @state.nowKey || @props.children[0]?.key

  setTabOffset: (offset) ->
    return if !@props.children?
    nowKey = @activeKey()
    React.Children.forEach @props.children, (child, index) =>
      if child.key == nowKey
        nextIndex = (index+offset) % @props.children.length
        @setNewKey @props.children[nextIndex].key

  render: ->
    showFirst = true
    <div>
    {
      React.Children.map @props.children, (child) =>
        # Show the first child at startup; o/w show the one with the correct key
        show = if !@state.nowKey? then showFirst else @state.nowKey == child.key
        showFirst = false
        className = classnames
          show: show
          hide: !show
        <div className={className}>
          {child}
        </div>
    }
    </div>

lockedTab = false
ControlledTabArea = React.createClass
  getInitialState: ->
    activePluginName: null
    key: [0, 0]
    plugins: []
    tabbedPlugins: []
  renderPlugins: async ->
    plugins = yield PluginManager.getValidPlugins()
    plugins = plugins.filter (plugin) ->
      plugin.show isnt false
    plugins = _.sortBy plugins, 'priority'
    tabbedPlugins = plugins.filter (plugin) ->
      !plugin.handleClick?
    if @isMounted()
      @setState
        plugins: plugins
        tabbedPlugins: tabbedPlugins
  handleSelect: (key) ->
    @setState {key} if key[0] isnt @state.key[0] or key[1] isnt @state.key[1]
  handleSelectLeft: (key) ->
    @handleSelect [key, @state.key[1]]
    if key in [0,1]
      eventKey = 'main'
    else if key == 1000
      eventKey = 'settings'
    if eventKey?
      event = new CustomEvent 'TabContentsUnion.show',
        bubbles: true
        cancelable: false
        detail:
          key: eventKey
      window.dispatchEvent event
  handleSelectRight: (e, key) ->
    e.preventDefault()
    plugin = @state.plugins.find (p) -> p.name == key
    return if !plugin?
    if !plugin.handleClick?
      @handleSelect [@state.key[0], key]
      event = new CustomEvent 'TabContentsUnion.show',
        bubbles: true
        cancelable: false
        detail:
          key: key
      window.dispatchEvent event
  handleSelectMainView: ->
    event = new CustomEvent 'view.main.visible',
      bubbles: true
      cancelable: false
      detail:
        visible: true
    window.dispatchEvent event
    @handleSelectLeft 0
  handleSelectShipView: ->
    @refs.mainTabUnion.
    event = new CustomEvent 'view.main.visible',
      bubbles: true
      cancelable: false
      detail:
        visible: false
    window.dispatchEvent event
    @handleSelectLeft 1
  handleCtrlOrCmdTabKeyDown: ->
    @handleSelect [(@state.key[0] + 1) % 1, @state.key[1]]
  handleCtrlOrCmdNumberKeyDown: (num) ->
    if num == 1
      @handleSelectMainView()
    else
      if num == 2
        @handleSelectShipView()
      else
        if num <= 2 + @state.tabbedPlugins.length && num > 2
          @handleSelect [@state.key[0], num - 3]
  handleShiftTabKeyDown: ->
    @refs.pluginTabUnion.setTabOffset -1
  handleTabKeyDown: ->
    @refs.pluginTabUnion.setTabOffset 1
  handleKeyDown: ->
    return if @listener?
    @listener = true
    window.addEventListener 'keydown', (e) =>
      if e.keyCode is 9
        e.preventDefault()
        return if lockedTab and e.repeat
        lockedTab = true
        setTimeout ->
          lockedTab = false
        , 200
        if e.ctrlKey or e.metaKey
          @handleCtrlOrCmdTabKeyDown()
        else if e.shiftKey
          @handleShiftTabKeyDown()
        else
          @handleTabKeyDown()
      else if e.ctrlKey or e.metaKey
        if e.keyCode >= 49 and e.keyCode <= 57
          @handleCtrlOrCmdNumberKeyDown(e.keyCode - 48)
        else if e.keyCode is 48
          @handleCtrlOrCmdNumberKeyDown 10
  componentDidMount: ->
    window.dispatchEvent new Event('resize')
    window.addEventListener 'game.start', @handleKeyDown
    window.addEventListener 'tabarea.reload', @forceUpdate
    window.addEventListener 'PluginManager.PLUGIN_RELOAD', @renderPlugins
    @renderPlugins()
  componentWillUnmount: ->
    window.removeEventListener 'PluginManager.PLUGIN_RELOAD', @renderPlugins
  render: ->
    activePluginName = @state.activePluginName || @state.plugins[0]?.name
    plugin = @state.plugins.find (p) => p.name == activePluginName
    <div className='poi-tabs-container'>
      <div>
        <Nav bsStyle="tabs" activeKey={@state.key[0]}>
          <NavItem key={0} eventKey={0} onSelect={@handleSelectMainView}>
            {mainview.displayName}
          </NavItem>
          <NavItem key={1} eventKey={1} onSelect={@handleSelectShipView}>
            <span><FontAwesome key={0} name='server' />{window.i18n.main.__ ' Fleet'}</span>
          </NavItem>
          <NavItem key={1000} eventKey={1000} className='poi-app-tabpane' onSelect={@handleSelectLeft}>
            {settings.displayName}
          </NavItem>
        </Nav>
        <TabContentsUnion ref='mainTabUnion'>
          <div id={mainview.name} className="poi-app-tabpane" key='main'>
            <mainview.reactClass />
          </div>
          <div id={settings.name} className="poi-app-tabpane" key='settings'>
            <settings.reactClass />
          </div>
        </TabContentsUnion>
      </div>
      <div>
        <Nav bsStyle="tabs" activeKey={@state.key[1]} onSelect={@handleSelectRight}>
          <NavDropdown id='plugin-dropdown' key={-1} eventKey={-1} pullRight
                       title={plugin?.displayName || <span><FontAwesome name='sitemap' />{__ ' Plugins'}</span>}>
          {
            @state.plugins.map (plugin) =>
              <MenuItem key={plugin.name} eventKey={plugin.name} onSelect={plugin.handleClick}>
                {plugin.displayName}
              </MenuItem>
          }
          {
            if @state.plugins.length == 0
              <MenuItem key={1001} disabled>{window.i18n.setting.__ "Install plugins in settings"}</MenuItem>
          }
          </NavDropdown>
        </Nav>
        {
          <TabContentsUnion ref='pluginTabUnion'
            onNewKey={(key) => @setState {activePluginName: key}}>
          {
            for plugin in @state.plugins when !plugin.handleClick?
              <div id={plugin.name} key={plugin.name} className="poi-app-tabpane">
                <PluginWrap plugin={plugin} />
              </div>
          }
          </TabContentsUnion>
        }
      </div>
    </div>
  
  

module.exports = ControlledTabArea
