# Test helper - requires chai and exposes assertions globally

chai = require 'chai'

global.should = chai.should()
global.expect = chai.expect
global.assert = chai.assert
