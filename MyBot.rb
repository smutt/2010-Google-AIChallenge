require './planetwars.rb'

# Implements our delayed order class
class DOrder
  attr_reader :orders

  def initialize()
    @orders = Array.new
  end

  def push(t, order)

    @orders.push([t,  order ])
  end

  def execute()
    @orders.each_index{ |ii|
      if(@orders[ii][0] == $turn)
        $dg.syswrite("\ndExec:" + @orders[ii][1].to_s)
        src, dest, ships = @orders[ii][1][0..2]
        $pw.issueOrder(src, dest, ships)
        @orders[ii] = nil
      end
    }
    @orders.compact!
  end

  def to_s
    return "empty" if(@orders.length <= 0)

    rv = ""
    @orders.each{ |t|
      rv += t.to_s
      rv += ", "
    }
    return rv.chop!.chop!
  end
end

# Logs a str to file
def flog(str)
  $dg.syswrite(str)
end

# Only called on the first turn
def doFirstTurn()
  flog("\ndoFirstTurn")

  mp = $pw.myPlanets
  home = mp[0]
  ep = $pw.enemyPlanets
  enemy = ep[0]
  
  # If the enemy's planet is closeby then CHARGE!!
  if($pw.distance(home, enemy) < 10)
    flog("\ndoFirst->charge:" + home.id.to_s + ":" + enemy.id.to_s + ":100")
    $pw.issueOrder(home.id, enemy.id, 100)
    $charge = true
    return
  end

  ships = 100
  ii = 0
  np = rankPlanets(home, 0)
  while ships > np[ii].ships
    flog("\nconsideringNeutralFirst:" + np[ii].id.to_s)
    if($pw.distance(home, np[ii]) > $maxDist + ($pw.distance(home, enemy) / 4)) # Don't even bother with this planet, it's too far away
      ii += 1
      next
    end
    if($pw.distance(home, np[ii]) > $pw.distance(enemy, np[ii])) #If our target neutral planet is closer to the enemy wait till next turn to attack it
      distDif = $pw.distance(home, np[ii]) - $pw.distance(enemy, np[ii])
      distDif = distDif.ceil + 1
      reqShips = np[ii].growth * (distDif + 1)
      flog("\nd.push:" + home.id.to_s + ":" + np[ii].id.to_s + ":" + reqShips.to_s)
      $d.push($turn + 1, [home.id, np[ii].id, reqShips])
      ships -= reqShips
    else
      reqShips =  np[ii].ships + 1
      if($pw.distance(home, np[ii]) < $maxDist)
        flog("\ndoFirst:" + home.id.to_s + ":" + np[ii].id.to_s + ":" + reqShips.to_s)
        $pw.issueOrder(home.id, np[ii].id, reqShips)
        ships -= reqShips
      end
    end
    ii += 1
  end
end

# Takes a planet and the owner of planets to rank
# Owner is either 0 for neutral or other player
# Returns planets sorted by want
# Want measured by distance, growth and number of ships
# Returns false if none found
def rankPlanets(home, owner)
  cheapies = Array.new
  if(owner == 0)
    fp = $pw.neutralPlanets
    cheapies = fp.select{ |p|
      p.ships < $discount
    }
  else
    fp = $pw.enemyPlanets
  end

  fp = fp.reject{ |p|
    p.ships > home.ships
  }
  return false if(fp.empty?)

  fp.each{ |p|
    dist = $pw.distance(home, p)
    if(dist > $maxDist)
      p.want = 0
    else
      p.ships = 1 if(p.ships == 0)
      p.want = p.growth*p.growth/dist/p.ships
    end
  }
  fp = fp.sort_by{ |p|
    -p.want
  }

  if(!cheapies.empty?)
    cheapies = cheapies.sort_by{ |p|
      $pw.distance(home, p)
    }
    return cheapies | fp
  else
    return fp
  end
end

# Returns total ships headed for a given planet
# Takes planetID and owner of fleets
# Owner is either 0 for other player or 1 for us
def dstFleets(pID, owner)
  tot=0
  if(owner == 0)
    $pw.enemyFleets.each{ |f|
      if(f.destPlanet == pID)
        tot += f.ships
      end
    }
  else
    $pw.myFleets.each{ |f|
      if(f.destPlanet == pID)
        tot += f.ships
      end
    }
  end

  return tot
end

# Finds the center of a given owner's empire
# Owner is either 0 for other player or 1 for us
# Returns x,y coordinates for center of empire
def findCenter(owner)
  totx = toty = tot = 0
  if(owner == 0)
    $pw.enemyPlanets.each{ |p|
      totx += p.x
      toty += p.y
      tot += 1
    }
  else
    $pw.myPlanets.each{ |p|
      totx += p.x
      toty += p.y
      tot += 1
    }
  end

  if(tot == 0)
    return false
  else
    x = totx/tot
    y = toty/tot 
    return x,y
  end
end

# Attacks enemy planets
# Takes a source planet
def attackEnemy(src)
  if(maybes = rankPlanets(src, 2))
    maybes.each{ |dest|
      return if(src.ships == 0 || src.ships == 1)
      flog("\nconsideringEnemy:" + src.id.to_s + "-->" + dest.id.to_s)
      ships = 1 + dest.ships + (dest.growth * ($pw.distance(src, dest) + 1))
      ships = ships.ceil
      if(src.ships > ships) # Do we have enough ships?
        if(dest.ships > dstFleets(dest.id, 1) * 2) # Are there already enough on the way?
          if(src.ships > dstFleets(src.id, 0) + ships) # Are we leaving the house unguarded?
            flog("\nenemy:" + src.id.to_s + ":" + dest.id.to_s + ":" + ships.to_s)
            $pw.issueOrder(src.id, dest.id, ships)
          end
        end
      else
        # Send the max safe amt of ships to our bitch
        if(dstFleets(src.id, 0) > src.ships) # Prolly fucked anyways
          next
        else
          ships = src.ships - dstFleets(src.id, 0) - 1
          next if(ships <= 0)
          flog("\nenemySafeMax:" + src.ships.to_s + ":" + src.id.to_s + ":" + $tPlanet.id.to_s + ":" + ships.to_s)
          $pw.issueOrder(src.id, $tPlanet.id, ships)
        end
      end
    }
  end
end

# Attacks neutral planets
# Takes a source planet
def attackNeutral(src)
  if(maybes = rankPlanets(src, 0))
    dest = maybes[0]
    flog("\nconsideringNeutral:" + src.id.to_s + "-->" + dest.id.to_s)
    ships = dest.ships + 1
    if(src.ships > ships) # Do we have enough ships?
      if(ships > dstFleets(dest.id, 1)) # Are there already enough on the way?
        if(src.ships > dstFleets(src.id, 0) + ships) # Are we leaving the house unguarded?
          flog("\nneutral:" + src.id.to_s + ":" + dest.id.to_s + ":" + ships.to_s)
          $pw.issueOrder(src.id, dest.id, ships)
        end
      end
    end
  end
end

# Perform a single turn
def doTurn()
  $turn += 1
  flog("\nTurn:" + $turn.to_s)
  $d.execute if($d.orders.length > 0)

  # If enemy has more ships but I have more growth do nothing
  eShips = fShips = eGrowth = fGrowth = 0
  $pw.enemyFleets.each{ |f|
    eShips += f.ships
  }
  $pw.myFleets.each{ |f|
    fShips += f.ships
  }
  $pw.enemyPlanets.each{ |p|
    eShips += p.ships
    eGrowth += p.growth
  }
  $pw.myPlanets.each{ |p|
    fShips += p.ships
    fGrowth += p.growth
  }
  if(eShips > fShips && fGrowth > eGrowth)
    flog("\ndoTurn:growReturn")
    return
  end

  # Determine tagged enemy planet
  # Tagged planet is our bitch and we send all excess ships to this planet until we take it
  mx, my = findCenter(1)
  if(mx && my)
    flog("\nenemyCenter:" + mx.to_s + ":" + my.to_s)
    if($tPlanet = $pw.getClosestPlanet(mx, my))
      flog("\ntPlanet:" + $tPlanet.id.to_s)
    else
      $tPlanet = $pw.myPlanets[0]
    end
  end

  mp = $pw.myPlanets.sort_by{ |x|
    x.ships
  }
  
  if($turn==1)
    doFirstTurn()
  else
    if($charge == false && $turn <= $musterTurns)
      mp.each{ |src|
        attackNeutral(src)
#        attackEnemy(src)
      }
    else
      mp.each{ |src|
        if(poss = rankPlanets(src, 0))
          if(poss[0].ships <= $discount)
            flog("\nneutralFirst:" + src.id.to_s)
            attackNeutral(src)
            attackEnemy(src)
          else
            flog("\nenemyFirst:" + src.id.to_s)
            attackEnemy(src)
            attackNeutral(src)
          end
        else
          attackEnemy(src)
          attackNeutral(src)
        end
      }
    end
  end
end


###########################
# BEGIN PROGRAM EXECUTION #
###########################

# Globals 
$dg = File.new('dg.txt', 'w')
$turn = 0
$maxDist = 15 # How far away do we consider planets to attack?
$discount = 11 # The ceilng for what we determine to be a cheap planet
$charge = false # Did we charge on the first turn
$musterTurns = 12 # How many turns do we muster our forces before attacking

# Array of delayed orders with turnID and order
# turnID tells which turn order should be executed
$d = DOrder.new

flog("\n\nExecution Started")
mapData = ''
loop do
  currentLine = gets.strip rescue break
  if currentLine.length >= 2 and currentLine[0..1] == "go"
    $pw = PlanetWars.new(mapData)
    doTurn()
    $pw.finishTurn
    mapData = ''
  else
    mapData += currentLine + "\n"
  end
end

$dg.close
