# The main namespace for the Roby library. The namespace is divided as follows:
#
# [Roby] core namespace for the Roby kernel
# [Roby::Distributed] parts that are very specific to distributed plan management
# [Roby::Planning] basic tools for plan generation
# [Roby::Transactions] implementation of transactions
# [Roby::EventStructure] event relations
# [Roby::TaskStructure] task relations
module Roby
    class BasicObject; end
    class PlanObject < BasicObject; end
    class Plan < BasicObject; end
    class Control; end
    class EventGenerator < PlanObject; end
    class Task < PlanObject; end
end

require 'drb'
require 'pp'
require 'thread'
require 'set'
require 'yaml'
require 'utilrb/value_set'
require 'utilrb/object/attribute'
require 'utilrb/module/ancestor_p'
require 'utilrb/kernel/options'
require 'utilrb/module/attr_enumerable'
require 'utilrb/module/attr_predicate'
require 'utilrb/module/inherited_enumerable'
require 'utilrb/module/include'
require 'utilrb/kernel/arity'
require 'utilrb/kernel/swap'
require 'utilrb/exception/full_message'
require 'utilrb/unbound_method/call'

require 'roby/config.rb'
require 'roby/support.rb'
require 'roby/basic_object.rb'
require 'roby/standard_errors.rb'
require 'roby/exceptions.rb'
require 'roby_bgl'
require 'roby/graph.rb'
require 'roby/relations.rb'

require 'roby/plan-object.rb'
require 'roby/event.rb'
require 'roby/task.rb'
require 'roby/task-operations.rb'

require 'roby/relations/conflicts.rb'
require 'roby/relations/ensured.rb'
require 'roby/relations/error_handling.rb'
require 'roby/relations/events.rb'
require 'roby/relations/executed_by.rb'
require 'roby/relations/hierarchy.rb'
require 'roby/relations/influence.rb'
require 'roby/relations/planned_by.rb'

require 'roby/task_index.rb'
require 'roby/plan.rb'
require 'roby/transactions/proxy.rb'
require 'roby/transactions.rb'
require 'roby/transactions/updates.rb'
require 'roby/query.rb'

require 'roby/distributed/base'
require 'roby/control.rb'
require 'roby/decision_control.rb'
require 'roby/propagation.rb'
require 'roby/app.rb'

require 'roby/robot.rb'
require 'roby/planning.rb'
require 'roby/state.rb'
