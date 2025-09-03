module flota_taxis::flota_taxis {
    use std::string::{String, utf8};
    use sui::vec_map::VecMap;

    public struct EmpresaTaxis has key, store {
        id: sui::object::UID,
        nombre_empresa: String,
        vehiculos: VecMap<u16, Taxi>,
        carreras_totales: u64,
        ingresos_acumulados: u64,
        licencia_operacion: String,
    }

    public struct Taxi has store, drop {
        conductor: String,
        placa: String,
        id_taxi: u16,
        cliente_actual: String,
        estado_servicio: String,
        carreras_completadas: u64,
        tarifa_actual: u64,
        zona_operacion: String,
    }

    public struct GerenceCap has key, store {
        id: sui::object::UID,
    }

    public struct TaxiRegistrado has copy, drop {
        id_taxi: u16,
        conductor: String,
        placa: String,
        zona_operacion: String,
    }

    public struct ServicioIniciado has copy, drop {
        id_taxi: u16,
        cliente: String,
        tarifa: u64,
        zona: String,
    }

    public struct ServicioCompletado has copy, drop {
        id_taxi: u16,
        tarifa_cobrada: u64,
        cliente_atendido: String,
    }

    public struct ConductorCambiado has copy, drop {
        id_taxi: u16,
        conductor_anterior: String,
        conductor_nuevo: String,
    }

    const E_ID_TAXI_DUPLICADO: u64 = 1;
    const E_TAXI_NO_EXISTE: u64 = 2;
    const E_TAXI_OCUPADO: u64 = 3;
    const E_TAXI_DISPONIBLE: u64 = 4;
    const E_TARIFA_INVALIDA: u64 = 6;

    public fun crear_empresa_taxis(
        nombre_empresa: String, 
        licencia: String, 
        ctx: &mut sui::tx_context::TxContext
    ): (EmpresaTaxis, GerenceCap) {
        let empresa = EmpresaTaxis {
            id: sui::object::new(ctx),
            nombre_empresa,
            vehiculos: sui::vec_map::empty(),
            carreras_totales: 0,
            ingresos_acumulados: 0,
            licencia_operacion: licencia,
        };
        
        let gerente_cap = GerenceCap {
            id: sui::object::new(ctx),
        };
        
        (empresa, gerente_cap)
    }

    public fun registrar_taxi(
        empresa: &mut EmpresaTaxis, 
        _: &GerenceCap,
        conductor: String, 
        placa: String, 
        id_taxi: u16,
        zona: String
    ) {
        assert!(!empresa.vehiculos.contains(&id_taxi), E_ID_TAXI_DUPLICADO);
        
        let nuevo_taxi = Taxi {
            conductor,
            placa,
            id_taxi,
            cliente_actual: utf8(b""),
            estado_servicio: utf8(b"Disponible"),
            carreras_completadas: 0,
            tarifa_actual: 0,
            zona_operacion: zona,
        };
        
        sui::event::emit(TaxiRegistrado {
            id_taxi,
            conductor: nuevo_taxi.conductor,
            placa: nuevo_taxi.placa,
            zona_operacion: nuevo_taxi.zona_operacion,
        });
        
        empresa.vehiculos.insert(id_taxi, nuevo_taxi);
    }

    public fun iniciar_servicio(
        empresa: &mut EmpresaTaxis, 
        _: &GerenceCap,
        id_taxi: u16, 
        nombre_cliente: String,
        tarifa_estimada: u64
    ) {
        assert!(empresa.vehiculos.contains(&id_taxi), E_TAXI_NO_EXISTE);
        assert!(tarifa_estimada > 0, E_TARIFA_INVALIDA);
        
        let taxi = empresa.vehiculos.get_mut(&id_taxi);
        
        assert!(taxi.estado_servicio == utf8(b"Disponible"), E_TAXI_OCUPADO);
        
        taxi.cliente_actual = nombre_cliente;
        taxi.estado_servicio = utf8(b"En servicio");
        taxi.tarifa_actual = tarifa_estimada;
        
        sui::event::emit(ServicioIniciado {
            id_taxi,
            cliente: nombre_cliente,
            tarifa: tarifa_estimada,
            zona: taxi.zona_operacion,
        });
    }

    public fun completar_servicio(
        empresa: &mut EmpresaTaxis, 
        _: &GerenceCap, 
        id_taxi: u16,
        tarifa_final: u64
    ) {
        assert!(empresa.vehiculos.contains(&id_taxi), E_TAXI_NO_EXISTE);
        assert!(tarifa_final > 0, E_TARIFA_INVALIDA);
        
        let taxi = empresa.vehiculos.get_mut(&id_taxi);
        
        assert!(taxi.estado_servicio == utf8(b"En servicio"), E_TAXI_DISPONIBLE);
        
        let cliente_atendido = taxi.cliente_actual;
        
        taxi.cliente_actual = utf8(b"");
        taxi.estado_servicio = utf8(b"Disponible");
        taxi.carreras_completadas = taxi.carreras_completadas + 1;
        taxi.tarifa_actual = 0;
        
        empresa.carreras_totales = empresa.carreras_totales + 1;
        empresa.ingresos_acumulados = empresa.ingresos_acumulados + tarifa_final;
        
        sui::event::emit(ServicioCompletado {
            id_taxi,
            tarifa_cobrada: tarifa_final,
            cliente_atendido,
        });
    }

    public fun eliminar_taxi(empresa: &mut EmpresaTaxis, _: &GerenceCap, id_taxi: u16) {
        assert!(empresa.vehiculos.contains(&id_taxi), E_TAXI_NO_EXISTE);
        
        let taxi = empresa.vehiculos.get(&id_taxi);
        assert!(taxi.estado_servicio == utf8(b"Disponible"), E_TAXI_OCUPADO);
        
        empresa.vehiculos.remove(&id_taxi);
    }

    public fun cambiar_conductor(
        empresa: &mut EmpresaTaxis, 
        _: &GerenceCap,
        id_taxi: u16, 
        nuevo_conductor: String
    ) {
        assert!(empresa.vehiculos.contains(&id_taxi), E_TAXI_NO_EXISTE);
        
        let taxi = empresa.vehiculos.get_mut(&id_taxi);
        let conductor_anterior = taxi.conductor;
        taxi.conductor = nuevo_conductor;
        
        sui::event::emit(ConductorCambiado {
            id_taxi,
            conductor_anterior,
            conductor_nuevo: taxi.conductor,
        });
    }

    public fun cambiar_zona_operacion(
        empresa: &mut EmpresaTaxis, 
        _: &GerenceCap,
        id_taxi: u16, 
        nueva_zona: String
    ) {
        assert!(empresa.vehiculos.contains(&id_taxi), E_TAXI_NO_EXISTE);
        
        let taxi = empresa.vehiculos.get_mut(&id_taxi);
        taxi.zona_operacion = nueva_zona;
    }
    
    public fun obtener_info_taxi(empresa: &EmpresaTaxis, id_taxi: u16): (String, String, String, String, u64, String) {
        assert!(empresa.vehiculos.contains(&id_taxi), E_TAXI_NO_EXISTE);
        
        let taxi = empresa.vehiculos.get(&id_taxi);
        (
            taxi.conductor, 
            taxi.placa, 
            taxi.cliente_actual, 
            taxi.estado_servicio, 
            taxi.carreras_completadas,
            taxi.zona_operacion
        )
    }

    public fun obtener_estadisticas_empresa(empresa: &EmpresaTaxis): (String, String, u64, u64, u64) {
        (
            empresa.nombre_empresa, 
            empresa.licencia_operacion,
            empresa.vehiculos.length(), 
            empresa.carreras_totales, 
            empresa.ingresos_acumulados
        )
    }

    public fun taxi_existe(empresa: &EmpresaTaxis, id_taxi: u16): bool {
        empresa.vehiculos.contains(&id_taxi)
    }

    public fun obtener_nombre_empresa(empresa: &EmpresaTaxis): String {
        empresa.nombre_empresa
    }

    public fun total_taxis_flota(empresa: &EmpresaTaxis): u64 {
        empresa.vehiculos.length()
    }

    public fun obtener_ingresos_totales(empresa: &EmpresaTaxis): u64 {
        empresa.ingresos_acumulados
    }
    
    entry fun crear_y_compartir_empresa(
        nombre_empresa: String, 
        licencia: String, 
        ctx: &mut sui::tx_context::TxContext
    ) {
        let (empresa, gerente_cap) = crear_empresa_taxis(nombre_empresa, licencia, ctx);
        let sender = sui::tx_context::sender(ctx);
        
        sui::transfer::transfer(gerente_cap, sender);
        sui::transfer::share_object(empresa);
    }

    public fun entry_registrar_taxi(
        empresa: &mut EmpresaTaxis,
        gerente_cap: &GerenceCap,
        conductor: String,
        placa: String,
        id_taxi: u16,
        zona: String
    ) {
        registrar_taxi(empresa, gerente_cap, conductor, placa, id_taxi, zona);
    }

    public fun entry_iniciar_servicio(
        empresa: &mut EmpresaTaxis,
        gerente_cap: &GerenceCap,
        id_taxi: u16,
        nombre_cliente: String,
        tarifa_estimada: u64
    ) {
        iniciar_servicio(empresa, gerente_cap, id_taxi, nombre_cliente, tarifa_estimada);
    }

    public fun entry_completar_servicio(
        empresa: &mut EmpresaTaxis,
        gerente_cap: &GerenceCap,
        id_taxi: u16,
        tarifa_final: u64
    ) {
        completar_servicio(empresa, gerente_cap, id_taxi, tarifa_final);
    }

    public fun entry_cambiar_conductor(
        empresa: &mut EmpresaTaxis,
        gerente_cap: &GerenceCap,
        id_taxi: u16,
        nuevo_conductor: String
    ) {
        cambiar_conductor(empresa, gerente_cap, id_taxi, nuevo_conductor);
    }
}