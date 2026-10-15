package com.apuestas.servicio;
import com.apuestas.dao.*;
import com.apuestas.modelo.*;
import com.apuestas.modelo.ConsultasAdministrativasModelos.*;
import java.sql.SQLException;
import java.util.*;
public class ConsultasAdministrativasServicio {
    private final EventoDAO eventos;private final AdministracionUsuarioDAO usuarios;private final UbicacionDAO ubicacion;
    public ConsultasAdministrativasServicio(){this(new EventoDAO(),new AdministracionUsuarioDAO(),new UbicacionDAO());}
    public ConsultasAdministrativasServicio(EventoDAO e,AdministracionUsuarioDAO u,UbicacionDAO p){eventos=Objects.requireNonNull(e);usuarios=Objects.requireNonNull(u);ubicacion=Objects.requireNonNull(p);}
    public Object consultar(OperacionConsultaAdministrativa op,int actor,String rol,Map<String,String[]> params)throws SQLException {
        if(op==null)throw new IllegalArgumentException();
        if(op==OperacionConsultaAdministrativa.USUARIOS)AdministracionUsuarioServicio.autorizar(actor,rol,true);
        else if(op==OperacionConsultaAdministrativa.PAISES)AdministracionEventosServicio.autorizar(actor,rol);
        else if(actor<=0||!com.apuestas.seguridad.SesionAdministrativa.rolPermitido(rol))throw new SecurityException();
        if(params==null)throw new IllegalArgumentException();
        for(Map.Entry<String,String[]> e:params.entrySet())if(!op.parametros.contains(e.getKey())||e.getValue()==null||e.getValue().length!=1||e.getValue()[0]==null)throw new IllegalArgumentException();
        if(op==OperacionConsultaAdministrativa.PAISES){
            List<PaisBasico> filas=new ArrayList<>();Set<Integer> ids=new HashSet<>();
            for(Pais p:Objects.requireNonNull(ubicacion.listarPaisesActivos())){
                if(p==null||p.getIdPais()<=0||p.getNombre()==null||p.getNombre().trim().isEmpty()||!ids.add(p.getIdPais()))throw new SQLException("Catalogo inconsistente.");
                filas.add(new PaisBasico(p.getIdPais(),p.getNombre()));
            }
            return new Paises(filas);
        }
        int pagina=numero(params,"pagina",1),tamano=numero(params,"tamanoPagina",50);
        if(tamano>100||((long)pagina-1)*tamano>Integer.MAX_VALUE)throw new IllegalArgumentException();
        if(op==OperacionConsultaAdministrativa.USUARIOS){
            String buscar=params.containsKey("buscar")?params.get("buscar")[0]:"";
            if(buscar.length()>150)throw new IllegalArgumentException();
            return Objects.requireNonNull(usuarios.buscarUsuarios(buscar.trim(),pagina,tamano));
        }
        Integer deporte=params.containsKey("idDeporte")?numero(params,"idDeporte",1):null;
        String estado=params.containsKey("estado")?params.get("estado")[0].trim():null;
        if(estado!=null&&!Arrays.asList("BORRADOR","PROGRAMADO","EN_VIVO","SUSPENDIDO","PENDIENTE_RESULTADO","FINALIZADO","CANCELADO").contains(estado))throw new IllegalArgumentException();
        return Objects.requireNonNull(eventos.listarSelectores(deporte,estado,pagina,tamano));
    }
    private static int numero(Map<String,String[]> p,String k,int defecto){if(!p.containsKey(k))return defecto;String s=p.get(k)[0];if(!s.matches("[0-9]{1,10}"))throw new IllegalArgumentException();int n=Integer.parseInt(s);if(n<=0)throw new IllegalArgumentException();return n;}
}
