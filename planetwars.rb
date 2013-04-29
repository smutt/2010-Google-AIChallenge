class Fleet
  attr_reader :owner, :ships, :srcPlanet, 
    :destPlanet, :totalTripLength, :turnsRemaining
 
   def initialize(owner, ships, srcPlanet, 
                 destPlanet, totalTripLength, 
                 turnsRemaining)
    @owner, @ships = owner, ships
    @srcPlanet = srcPlanet
    @destPlanet = destPlanet
    @totalTripLength = totalTripLength
    @turnsRemaining = turnsRemaining
  end
end

class Planet
  attr_reader :id, :growth, :x, :y
  attr_accessor :owner, :ships, :want

  def initialize(id, owner, ships, growth, x, y)
    @id, @owner, @ships = id, owner, ships
    @growth, @x, @y = growth, x, y
  end

  def addShips(n)
    @ships += amt
  end

  def removeShips(n)
    @ships -= n
  end
end

class PlanetWars
  attr_reader :planets, :fleets

  def initialize(gameState)
    parseGameState(gameState)
  end

  def numPlanets
    @planets.length
  end

  def getPlanet(id)
    @planets[id]
  end

  def numFleets
    @fleets.length
  end

  def getFleet(id)
    @fleets[id]
  end

  def myPlanets
    @planets.select {|planet| planet.owner == 1 }
  end

  def neutralPlanets
    @planets.select {|planet| planet.owner == 0 }
  end

  def enemyPlanets
    @planets.select {|planet| planet.owner > 1 }
  end

  def notMyPlanets
    @planets.reject {|planet| planet.owner == 1 }
  end

  def myFleets
    @fleets.select {|fleet| fleet.owner == 1 }
  end

  def enemyFleets
    @fleets.select {|fleet| fleet.owner > 1 }
  end

  def to_s
    s = []
    @planets.each do |p|
      s << "P #{p.x} #{p.y} #{p.owner} #{p.ships} #{p.growth}"
    end
    @fleets.each do |f|
      s << "F #{f.owner} #{f.ships} #{f.srcPlanet} #{f.destPlanet} #{f.totalTripLength} #{f.turnsRemaining}"
    end
    return s.join("\n")
  end

  def distance(src, dest)
    Math::hypot( (src.x - dest.x), (src.y - dest.y) )
  end

  def travelTime(src, dest)
    distance(src, dest).ceil
  end

  # Returns enemy planet closest to x,y coordinates
  def getClosestPlanet(x, y)
    return false if(self.enemyPlanets.length <= 0)
    rv = self.enemyPlanets[0]
    self.enemyPlanets.each{ |p|
      rv = p if(Math::hypot((x - p.x), (y - p.y)) < Math::hypot((x - rv.x), (y - rv.y)))
    }

    return rv
  end

  # This takes 2 Planet IDs
  def issueOrder(src, dest, ships)
#    $dg.syswrite("\nRXOrder:" + src.to_s + ":" + dest.to_s + ":" + ships.to_s)

    # This should NEVER eval to true
    return if(ships <= 0 || ships > @planets[src].ships)

    duration = travelTime(@planets[src], @planets[dest])
    f = Fleet.new(1, ships, src, dest, duration, duration)
    @fleets << f
    @planets[src].ships -= ships

#    $dg.syswrite("\nTXOrder:" + src.to_s + ":" + dest.to_s + ":" + ships.to_s)
    puts "#{src} #{dest} #{ships}"
    STDOUT.flush
  end

  def isAlive(pID)
    ((@planets.select{|p| p.owner == pID }).length > 0) || ((@fleets.select{|p| p.owner == pID }).length > 0)
  end

  def parseGameState(s)
    @planets = []
    @fleets = []
    lines = s.split("\n")
    planetID = 0

    lines.each do |line|
      line = line.split("#")[0]
      tokens = line.split(" ")
      next if tokens.length == 1
      if tokens[0] == "P"
        return 0 if tokens.length != 6
        p = Planet.new(planetID,
                       tokens[3].to_i, # owner
                       tokens[4].to_i, # ships
                       tokens[5].to_i, # growth
                       tokens[1].to_f, # x
                       tokens[2].to_f) # y
        planetID += 1
        @planets << p
      elsif tokens[0] == "F"
        return 0 if tokens.length != 7
        f = Fleet.new(tokens[1].to_i, # owner
                      tokens[2].to_i, # ships
                      tokens[3].to_i, # source
                      tokens[4].to_i, # destination
                      tokens[5].to_i, # totalTripLength
                      tokens[6].to_i) # turnsRemaining
        @fleets << f
      else
        return 0
      end
    end
    return 1
  end

  def finishTurn
    puts "go"
    STDOUT.flush
  end
end
