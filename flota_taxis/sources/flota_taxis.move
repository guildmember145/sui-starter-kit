module flota_taxis::flota_taxis {
    /// Módulo para gestionar una flota de taxis en la blockchain de Sui.
    use std::string::String;
    use sui::vec_map::{Self, VecMap};
    
    /// Código de error cuando un ID de taxi ya existe en la flota.
    const E_ID_YA_EXISTE: u64 = 1;

    /// Representa una flota de taxis, almacenando un ID único y un mapa de taxis.
    public struct FlotaTaxis has key {
        id: sui::object::UID,
        taxis: VecMap<u64, Taxi>
    }

    /// Representa un solo taxi con sus atributos.
    public struct Taxi has store, drop {
        placa: String, // Placa del vehículo
        conductor: String, // Nombre del conductor
        modelo: u16, // Año del modelo
        disponible: bool, // Estado de disponibilidad
    }

    /// Crea una nueva flota de taxis y transfiere la propiedad al llamador.
    #[allow(lint(self_transfer))]
    public fun crear_flota(ctx: &mut sui::tx_context::TxContext) {
        let flota = FlotaTaxis {
            id: sui::object::new(ctx),
            taxis: vec_map::empty(),
        };
        sui::transfer::transfer(flota, sui::tx_context::sender(ctx));
    }

    /// Agrega un nuevo taxi a la flota con el ID y atributos proporcionados.
    /// Falla si el ID ya existe.
    public fun agregar_taxi(
        flota: &mut FlotaTaxis,
        id_taxi: u64,
        placa: String,
        conductor: String,
        modelo: u16,
    ) {
        assert!(!flota.taxis.contains(&id_taxi), E_ID_YA_EXISTE);
        let taxi = Taxi {
            placa,
            conductor,
            modelo,
            disponible: true,
        };
        flota.taxis.insert(id_taxi, taxi);
    }

    /// Edita la placa de un taxi en la flota.
    public fun editar_placa(flota: &mut FlotaTaxis, id_taxi: u64, placa_nueva: String) {
        let taxi = flota.taxis.get_mut(&id_taxi);
        taxi.placa = placa_nueva;
    }

    /// Edita el nombre del conductor de un taxi en la flota.
    public fun editar_conductor(flota: &mut FlotaTaxis, id_taxi: u64, conductor_nuevo: String) {
        let taxi = flota.taxis.get_mut(&id_taxi);
        taxi.conductor = conductor_nuevo;
    }

    /// Edita el año del modelo de un taxi en la flota.
    public fun editar_modelo(flota: &mut FlotaTaxis, id_taxi: u64, modelo_nuevo: u16) {
        let taxi = flota.taxis.get_mut(&id_taxi);
        taxi.modelo = modelo_nuevo;
    }

    /// Edita el estado de disponibilidad de un taxi en la flota.
    public fun editar_disponibilidad(flota: &mut FlotaTaxis, id_taxi: u64, disponible_nuevo: bool) {
        let taxi = flota.taxis.get_mut(&id_taxi);
        taxi.disponible = disponible_nuevo;
    }

    /// Elimina un taxi de la flota por su ID.
    public fun eliminar_taxi(flota: &mut FlotaTaxis, id_taxi: u64) {
        flota.taxis.remove(&id_taxi);
    }

    /// Elimina toda la flota de taxis, incluyendo su ID.
    public fun eliminar_flota(flota: FlotaTaxis) {
        let FlotaTaxis { id, taxis: _ } = flota;
        id.delete();
    }
}