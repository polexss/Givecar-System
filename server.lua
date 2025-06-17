local Config = require 'config'

-- Cheat&Optimize
lib.addCommand(Config.CommandName, {
    help = 'Bir oyuncuya araç verir ve veritabanına kaydeder',
    restricted = false, -- manuel
    params = {
        { name = Config.Params.id, help = 'Oyuncu ID', type = 'number' },
        { name = Config.Params.model, help = 'Araç modeli', type = 'string' }
    }
}, function(source, args)
    local src = source

    -- permission check
    local allowed = false
    for perm in pairs(Config.AllowedGroups) do
        if IsPlayerAceAllowed(src, 'group.'..perm) and Config.AllowedGroups[perm] then
            allowed = true
            break
        end
    end
    if not allowed then
        return lib.notify(src, {
            title = 'Yetki Yok',
            description = 'Bu komutu kullanmaya yetkin yok.',
            type = 'error'
        })
    end

    local target = args[Config.Params.id]
    local model = args[Config.Params.model]:lower()

    if not target or not GetPlayerPed(target) then
        return lib.notify(src, {
            title = 'GiveCar',
            description = 'Geçersiz oyuncu ID.',
            type = 'error'
        })
    end

    if not model or #model < Config.MinModelLength or not IsModelInCdimage(model) then
        return lib.notify(src, {
            title = 'GiveCar',
            description = 'Geçersiz araç modeli.',
            type = 'error'
        })
    end

    local ped = GetPlayerPed(target)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local netId = qbx.spawnVehicle({
        model = model,
        coords = vec4(coords.x, coords.y, coords.z + 1.0, heading),
        warp = ped,
    })

    local entity = NetworkGetEntityFromNetworkId(netId)
    Wait(100)

    local plate = GetVehicleNumberPlateText(entity)
    local props = lib.getVehicleProperties(entity)
    props.plate = plate

    local player = exports.qbx_core:GetPlayer(target)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    if not citizenid or not plate then return end

    -- check
    local existing = MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ?', { plate })
    if existing then
        return lib.notify(src, {
            title = 'GiveCar',
            description = 'Bu plaka zaten veritabanında kayıtlı.',
            type = 'error'
        })
    end

    MySQL.insert.await('INSERT INTO owned_vehicles (citizenid, plate, vehicle, state) VALUES (?, ?, ?, ?)', {
        citizenid,
        plate,
        json.encode(props),
        0
    })

    lib.notify(src, {
        title = 'GiveCar',
        description = ('%s plakalı %s başarıyla verildi.'):format(plate, model),
        type = 'success'
    })

    lib.notify(target, {
        title = 'Yeni Araç',
        description = ('%s plakalı %s aracı sana verildi.'):format(plate, model),
        type = 'inform'
    })
end)
