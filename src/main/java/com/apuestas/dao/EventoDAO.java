/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.dao;
import com.apuestas.modelo.Evento;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
/**
 *
 * @author farfa
 */
public class EventoDAO {

    public Evento crearEvento(int idUsuarioProceso,
                              Evento evento,
                              String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_CrearEvento(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, evento.getIdLiga());
            cs.setString(3, evento.getNombre());

            cs.setTimestamp(
                    4,
                    Timestamp.valueOf(evento.getFechaInicio())
            );

            if (evento.getFechaFin() != null) {

                cs.setTimestamp(
                        5,
                        Timestamp.valueOf(evento.getFechaFin())
                );

            } else {

                cs.setNull(
                        5,
                        Types.TIMESTAMP
                );
            }

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearEvento(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_CrearEvento no devolvió el evento creado.");
    }

    public Evento actualizarEvento(int idUsuarioProceso,
                                   Evento evento,
                                   String ipOrigen)
            throws SQLException {

        String sql =
                "{call dbo.sp_ActualizarEvento(?, ?, ?, ?, ?, ?)}";

        try (Connection conexion = ConexionBD.obtenerConexion();
             CallableStatement cs = conexion.prepareCall(sql)) {

            cs.setInt(1, idUsuarioProceso);
            cs.setInt(2, evento.getIdEvento());
            cs.setString(3, evento.getNombre());

            cs.setTimestamp(
                    4,
                    Timestamp.valueOf(evento.getFechaInicio())
            );

            if (evento.getFechaFin() != null) {

                cs.setTimestamp(
                        5,
                        Timestamp.valueOf(evento.getFechaFin())
                );

            } else {

                cs.setNull(
                        5,
                        Types.TIMESTAMP
                );
            }

            establecerIp(cs, 6, ipOrigen);

            try (ResultSet rs = cs.executeQuery()) {

                if (rs.next()) {
                    return mapearEvento(rs);
                }
            }
        }

        throw new SQLException(
                "El procedimiento sp_ActualizarEvento no devolvió el evento actualizado.");
    }

    public List<Evento> listarEventos()
            throws SQLException {

        List<Evento> eventos =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "EV.IdEvento, "
                + "EV.IdLiga, "
                + "EV.IdEstado, "
                + "E.Codigo AS EstadoEvento, "
                + "EV.Nombre, "
                + "EV.FechaInicio, "
                + "EV.FechaFin "
                + "FROM dbo.Evento EV "
                + "INNER JOIN dbo.Estado E "
                + "ON E.IdEstado = EV.IdEstado "
                + "ORDER BY EV.FechaInicio";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql);
             ResultSet rs =
                     ps.executeQuery()) {

            while (rs.next()) {
                eventos.add(
                        mapearEvento(rs));
            }
        }

        return eventos;
    }

    public List<Evento> listarEventosPorLiga(
            int idLiga)
            throws SQLException {

        List<Evento> eventos =
                new ArrayList<>();

        String sql =
                "SELECT "
                + "EV.IdEvento, "
                + "EV.IdLiga, "
                + "EV.IdEstado, "
                + "E.Codigo AS EstadoEvento, "
                + "EV.Nombre, "
                + "EV.FechaInicio, "
                + "EV.FechaFin "
                + "FROM dbo.Evento EV "
                + "INNER JOIN dbo.Estado E "
                + "ON E.IdEstado = EV.IdEstado "
                + "WHERE EV.IdLiga = ? "
                + "ORDER BY EV.FechaInicio";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idLiga);

            try (ResultSet rs =
                         ps.executeQuery()) {

                while (rs.next()) {
                    eventos.add(
                            mapearEvento(rs));
                }
            }
        }

        return eventos;
    }

    public Evento buscarPorId(
            int idEvento)
            throws SQLException {

        String sql =
                "SELECT "
                + "EV.IdEvento, "
                + "EV.IdLiga, "
                + "EV.IdEstado, "
                + "E.Codigo AS EstadoEvento, "
                + "EV.Nombre, "
                + "EV.FechaInicio, "
                + "EV.FechaFin "
                + "FROM dbo.Evento EV "
                + "INNER JOIN dbo.Estado E "
                + "ON E.IdEstado = EV.IdEstado "
                + "WHERE EV.IdEvento = ?";

        try (Connection conexion =
                     ConexionBD.obtenerConexion();
             PreparedStatement ps =
                     conexion.prepareStatement(sql)) {

            ps.setInt(1, idEvento);

            try (ResultSet rs =
                         ps.executeQuery()) {

                if (rs.next()) {
                    return mapearEvento(rs);
                }
            }
        }

        return null;
    }

    protected Connection obtenerConexionSelector() throws SQLException {return ConexionBD.obtenerConexion();}
    /** Variante paginada de listarEventos: solo datos de identificacion, sin analitica financiera. */
    public com.apuestas.modelo.ConsultasAdministrativasModelos.PaginaEventos listarSelectores(
            Integer deporte,String estado,int pagina,int tamano) throws SQLException {
        return listarSelectores(deporte,estado,pagina,tamano,false);
    }
    public com.apuestas.modelo.ConsultasAdministrativasModelos.PaginaEventos listarSelectores(
            Integer deporte,String estado,int pagina,int tamano,boolean operables) throws SQLException {
        long offset=((long)pagina-1)*tamano;
        if(pagina<1||tamano<1||tamano>100||offset>Integer.MAX_VALUE||(deporte!=null&&deporte<=0))throw new IllegalArgumentException();
        if(operables&&estado!=null)throw new IllegalArgumentException();
        String from=" FROM dbo.Evento EV JOIN dbo.Liga L ON L.IdLiga=EV.IdLiga"
                +" JOIN dbo.Deporte D ON D.IdDeporte=L.IdDeporte JOIN dbo.Estado E ON E.IdEstado=EV.IdEstado"
                +" JOIN dbo.TipoEstado TE ON TE.IdTipoEstado=E.IdTipoEstado AND TE.Codigo='EVENTO'";
        String where=" WHERE 1=1"+(deporte==null?"":" AND L.IdDeporte=?")+(estado==null?"":" AND E.Codigo=?")
                +(operables?" AND E.Codigo IN ('PROGRAMADO','EN_VIVO','SUSPENDIDO','PENDIENTE_RESULTADO')":"");
        try(Connection c=obtenerConexionSelector()) {
            long total;
            try(PreparedStatement ps=c.prepareStatement("SELECT COUNT_BIG(*) AS Total"+from+where)) {
                parametrosSelector(ps,deporte,estado);
                try(ResultSet rs=ps.executeQuery()){if(!rs.next()||!(rs.getObject("Total") instanceof Long))throw new SQLException("Conteo inconsistente.");total=(Long)rs.getObject("Total");if(total<0||rs.next())throw new SQLException("Conteo inconsistente.");}
            }
            List<com.apuestas.modelo.ConsultasAdministrativasModelos.EventoSelector> filas=new ArrayList<>();
            String columnas="SELECT EV.IdEvento,L.IdDeporte,EV.IdLiga,EV.Nombre AS Evento,D.Nombre AS Deporte,L.Nombre AS Liga,EV.FechaInicio,E.Codigo AS EstadoEvento,"
                    +" (SELECT TOP(1) P.Nombre FROM dbo.EventoParticipante EP JOIN dbo.Participante P ON P.IdParticipante=EP.IdParticipante WHERE EP.IdEvento=EV.IdEvento ORDER BY EP.OrdenParticipante,EP.IdParticipante) AS Participante1,"
                    +" (SELECT P.Nombre FROM dbo.EventoParticipante EP JOIN dbo.Participante P ON P.IdParticipante=EP.IdParticipante WHERE EP.IdEvento=EV.IdEvento ORDER BY EP.OrdenParticipante,EP.IdParticipante OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY) AS Participante2";
            try(PreparedStatement ps=c.prepareStatement(columnas+from+where+" ORDER BY EV.FechaInicio DESC,EV.IdEvento DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY")) {
                int i=parametrosSelector(ps,deporte,estado);ps.setLong(i,offset);ps.setInt(i+1,tamano);
                try(ResultSet rs=ps.executeQuery()) {
                    while(rs.next()) {
                        com.apuestas.modelo.ConsultasAdministrativasModelos.EventoSelector v=new com.apuestas.modelo.ConsultasAdministrativasModelos.EventoSelector();
                        v.idEvento=rs.getInt("IdEvento");v.idDeporte=rs.getInt("IdDeporte");v.idLiga=rs.getInt("IdLiga");
                        v.evento=rs.getString("Evento");v.deporte=rs.getString("Deporte");v.liga=rs.getString("Liga");v.estadoEvento=rs.getString("EstadoEvento");
                        v.participante1=rs.getString("Participante1");v.participante2=rs.getString("Participante2");
                        Timestamp fecha=rs.getTimestamp("FechaInicio");v.fechaInicio=fecha==null?null:fecha.toLocalDateTime();
                        if(v.idEvento<=0||v.idDeporte<=0||v.idLiga<=0||v.evento==null||v.estadoEvento==null||v.fechaInicio==null||filas.size()>=tamano)throw new SQLException("Evento inconsistente.");
                        filas.add(v);
                    }
                }
            }
            return new com.apuestas.modelo.ConsultasAdministrativasModelos.PaginaEventos(pagina,tamano,total,filas);
        }
    }
    private static int parametrosSelector(PreparedStatement ps,Integer deporte,String estado)throws SQLException {
        int i=1;if(deporte!=null)ps.setInt(i++,deporte);if(estado!=null)ps.setString(i++,estado);return i;
    }

    private Evento mapearEvento(
            ResultSet rs)
            throws SQLException {

        Evento evento =
                new Evento();

        evento.setIdEvento(
                rs.getInt("IdEvento"));

        evento.setIdLiga(
                rs.getInt("IdLiga"));

        evento.setIdEstado(
                rs.getInt("IdEstado"));

        evento.setEstadoEvento(
                rs.getString("EstadoEvento"));

        evento.setNombre(
                rs.getString("Nombre"));

        Timestamp fechaInicio =
                rs.getTimestamp("FechaInicio");

        if (fechaInicio != null) {
            evento.setFechaInicio(
                    fechaInicio.toLocalDateTime());
        }

        Timestamp fechaFin =
                rs.getTimestamp("FechaFin");

        if (fechaFin != null) {
            evento.setFechaFin(
                    fechaFin.toLocalDateTime());
        }

        return evento;
    }

    private void establecerIp(
            CallableStatement cs,
            int parametro,
            String ipOrigen)
            throws SQLException {

        if (ipOrigen != null
                && !ipOrigen.trim().isEmpty()) {

            cs.setString(
                    parametro,
                    ipOrigen
            );

        } else {

            cs.setNull(
                    parametro,
                    Types.VARCHAR
            );
        }
    }
}
