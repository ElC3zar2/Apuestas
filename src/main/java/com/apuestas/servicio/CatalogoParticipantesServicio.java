package com.apuestas.servicio;

import com.apuestas.dao.ParticipanteDAO;
import com.apuestas.modelo.PaginaParticipantes;
import java.sql.SQLException;
import java.util.*;

/** Catalogo de lectura; misma autorizacion que administracion de eventos. */
public final class CatalogoParticipantesServicio {
    private final ParticipanteDAO dao;
    private static final Set<String> PARAMETROS=Collections.unmodifiableSet(new HashSet<>(
            Arrays.asList("idLiga","idDeporte","buscar","pagina","tamanoPagina","activo")));
    public CatalogoParticipantesServicio() {this(new ParticipanteDAO());}
    public CatalogoParticipantesServicio(ParticipanteDAO dao) {this.dao=Objects.requireNonNull(dao);}
    public PaginaParticipantes listar(int actor,String rol,Map<String,String[]> p) throws SQLException {
        AdministracionEventosServicio.autorizar(actor,rol);
        if(p==null) throw new IllegalArgumentException();
        for(Map.Entry<String,String[]> e:p.entrySet()) {
            if(!PARAMETROS.contains(e.getKey())||e.getValue()==null||e.getValue().length!=1||e.getValue()[0]==null)
                throw new IllegalArgumentException();
        }
        Integer deporte=p.containsKey("idDeporte")?numero(p,"idDeporte",1):null;
        int pagina=numero(p,"pagina",1),tamano=numero(p,"tamanoPagina",20);
        if(tamano>100||((long)pagina-1)*tamano>Integer.MAX_VALUE) throw new IllegalArgumentException();
        String buscar=p.containsKey("buscar")?p.get("buscar")[0]:"";
        if(buscar.length()>150) throw new IllegalArgumentException();
        buscar=buscar.trim();
        Boolean activo=null;
        if(p.containsKey("activo")) {
            String v=p.get("activo")[0];
            if(!"true".equals(v)&&!"false".equals(v)) throw new IllegalArgumentException();
            activo=Boolean.valueOf(v);
        }
        Integer liga=p.containsKey("idLiga")?numero(p,"idLiga",1):null;
        return Objects.requireNonNull(liga==null?dao.listarPaginados(deporte,buscar,activo,pagina,tamano):
                dao.listarPaginadosPorLiga(liga,deporte,buscar,activo,pagina,tamano));
    }
    private static int numero(Map<String,String[]> p,String nombre,int defecto) {
        if(!p.containsKey(nombre)) return defecto;
        String v=p.get(nombre)[0];if(!v.matches("[0-9]{1,10}")) throw new IllegalArgumentException();
        int n=Integer.parseInt(v);if(n<=0) throw new IllegalArgumentException();return n;
    }
}
