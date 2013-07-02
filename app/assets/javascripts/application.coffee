#####
#
# this manifest includes all javascript files that are used in both:
# the borrow section and the manage section of leihs
#
#= require_self
#
##### BOWER COMPONENTS
#
#= require jquery/jquery
#= require jquery-ui/ui/minified/jquery-ui.min
#= require jquery-ujs/src/rails
#= require jsrender/jsrender.min
#= require underscore/underscore-min
#
##### VENDOR
#
#= require bootstrap/bootstrap-modal
#= require tooltipster/tooltipster
#= require jquery.inview/jquery.inview
#= require jed/jed
#= require accounting/accounting
#= require moment/moment
#=
##### SPINE
#
#= require spine/spine
#= require spine/manager
#= require spine/ajax
#= require spine/relation
#
##### LIB
#
#= require_tree ./_NEW/lib
#= require_tree ./_NEW/modules
#= require_tree ./_NEW/models
#= require_tree ./_NEW/views
#
#####

window.App ?= {}
window.App.Modules ?= {}