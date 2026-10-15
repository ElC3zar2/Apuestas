package com.apuestas.modelo;
import java.time.LocalDateTime;
import java.util.*;
/** Proyecciones de lectura explicitas: nunca serializar entidades de autenticacion. */
public final class ConsultasAdministrativasModelos {
    private ConsultasAdministrativasModelos() { }
    public static final class EventoSelector {
        public Integer idEvento,idDeporte,idLiga;
        public String evento,deporte,liga,participante1,participante2,estadoEvento;
        public LocalDateTime fechaInicio;
    }
    public static final class UsuarioBusqueda {
        public Integer idUsuario;
        public String nombre,apellido,correo,estadoUsuario,rol;
    }
    public static final class PaisBasico {
        public final int idPais;public final String nombre;
        public PaisBasico(int id,String nombre){idPais=id;this.nombre=nombre;}
    }
    public static final class PaginaEventos {
        public final boolean ok=true;public final int pagina,tamanoPagina;public final long total;
        public final List<EventoSelector> eventos;
        public PaginaEventos(int p,int t,long n,List<EventoSelector> filas){pagina=p;tamanoPagina=t;total=n;eventos=Collections.unmodifiableList(new ArrayList<>(filas));}
    }
    public static final class PaginaUsuarios {
        public final boolean ok=true;public final int pagina,tamanoPagina;public final long total;
        public final List<UsuarioBusqueda> usuarios;
        public PaginaUsuarios(int p,int t,long n,List<UsuarioBusqueda> filas){pagina=p;tamanoPagina=t;total=n;usuarios=Collections.unmodifiableList(new ArrayList<>(filas));}
    }
    public static final class Paises {
        public final boolean ok=true;public final List<PaisBasico> paises;
        public Paises(List<PaisBasico> filas){paises=Collections.unmodifiableList(new ArrayList<>(filas));}
    }
}
