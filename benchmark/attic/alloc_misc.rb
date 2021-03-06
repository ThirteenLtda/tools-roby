require 'utilrb/objectstats'
require 'utilrb/value_set'
require 'enumerator'
require 'set'

GC.disable

puts "==== Iteration"
[(1..10_000), (1..10_000).to_a, (1..10_000).to_value_set, (1..10_000).enum_for, (1..10_000).to_set].each do |set|
    before = ObjectSpace.live_objects
    for obj in set
        10
    end
    after  = ObjectSpace.live_objects
    puts "#{set.class} for: #{after - before}"

    before = ObjectSpace.live_objects
    set.each { |obj| 10 }
    after  = ObjectSpace.live_objects
    puts "#{set.class} each: #{after - before}"
end

puts "\n===== Method calls"
def bm_args_yield(a, b)
    yield(a, b) if block_given?
end
def bm_args_yield_through_block(a, b, &block)
    block.call(a, b) if block
end

def bm_method_call
end

def bm_yield
    yield
end
def bm_block_yield(&block)
    yield
end

def bm_block(do_call, &block)
    block.call if do_call
end

class Test
    def bla
    end
end
class Foo < Test
    def bla
        super
    end
end


before = ObjectSpace.live_objects
bm_method_call
after  = ObjectSpace.live_objects
puts "Method call: #{after - before}"

test = Foo.new
before = ObjectSpace.live_objects
test.bla
after = ObjectSpace.live_objects
puts "Method call with super: #{after - before}"

before = ObjectSpace.live_objects
bm_method_call { 10 }
after  = ObjectSpace.live_objects
puts "Method call with block m(): #{after - before}"

before = ObjectSpace.live_objects
bm_block(false) { 10 }
after  = ObjectSpace.live_objects
puts "Method call with block m(&block): #{after - before}"

before = ObjectSpace.live_objects
bm_yield { 10 }
after  = ObjectSpace.live_objects
puts "Yield: #{after - before}"

before = ObjectSpace.live_objects
bm_block(true) { 10 }
after  = ObjectSpace.live_objects
puts "Block & #call: #{after - before}"

before = ObjectSpace.live_objects
bm_block_yield { 10 }
after  = ObjectSpace.live_objects
puts "Block and yield: #{after - before}"

p = Proc.new { 10 }
before = ObjectSpace.live_objects
p.call
after  = ObjectSpace.live_objects
puts "Proc#call: #{after - before}"

puts "\n=== Exceptions"
def bm_exception
rescue
ensure
end
before = ObjectSpace.live_objects
begin
rescue Exception
ensure
end
after  = ObjectSpace.live_objects
puts "begin-rescue-ensure: #{after - before}"

before = ObjectSpace.live_objects
bm_exception
after  = ObjectSpace.live_objects
puts "begin-rescue-ensure method: #{after - before}"

puts "\n=== Misc"
before = ObjectSpace.live_objects
defined? yield
after  = ObjectSpace.live_objects
puts "defined?: #{after - before}"



