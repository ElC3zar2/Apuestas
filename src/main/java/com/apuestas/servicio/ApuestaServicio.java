/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.apuestas.servicio;

import com.apuestas.dao.ApuestaDAO;
import com.apuestas.modelo.Boleto;
import com.apuestas.modelo.CotizacionApuesta;
import com.apuestas.modelo.ResultadoApuesta;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.List;
import java.util.UUID;

/**
 *
 * @author farfa
 */
public class ApuestaServicio {

    private final ApuestaDAO apuestaDAO;

    public ApuestaServicio() {
        this.apuestaDAO =
                new ApuestaDAO();
    }

    public ApuestaServicio(ApuestaDAO apuestaDAO) {
        this.apuestaDAO = java.util.Objects.requireNonNull(apuestaDAO);
    }

    public CotizacionApuesta cotizarApuesta(List<Integer> selecciones,BigDecimal monto) throws SQLException {
        return cotizarApuesta(selecciones,monto,null,null);
    }

    public CotizacionApuesta cotizarApuesta(List<Integer> selecciones,BigDecimal monto,
            Integer pronosticoA,Integer pronosticoB) throws SQLException {
        validarSelecciones(selecciones); validarMonto(monto); validarPronosticos(selecciones,pronosticoA,pronosticoB);
        CotizacionApuesta r=apuestaDAO.cotizarApuesta(construirSeleccionesJson(selecciones),monto,pronosticoA,pronosticoB);
        if(r==null || r.getDetalles()==null || r.getDetalles().size()!=selecciones.size())
            throw new SQLException("Respuesta de cotizacion inconsistente.");
        java.util.Set<Integer> recibidas=new java.util.HashSet<>();
        for(com.apuestas.modelo.DetalleCotizacionApuesta d:r.getDetalles()) recibidas.add(d.getIdSeleccion());
        if(!recibidas.equals(new java.util.HashSet<>(selecciones))) throw new SQLException("Selecciones inconsistentes.");
        return r;
    }

    public ResultadoApuesta realizarApuesta(int idUsuario,List<Integer> selecciones,BigDecimal monto,
            UUID referencia,String ip) throws SQLException {
        return realizarApuesta(idUsuario,selecciones,monto,referencia,ip,null,null);
    }

    public ResultadoApuesta realizarApuesta(int idUsuario,List<Integer> selecciones,BigDecimal monto,
            UUID referencia,String ip,Integer pronosticoA,Integer pronosticoB) throws SQLException {
        validarUsuario(idUsuario); validarSelecciones(selecciones); validarMonto(monto);
        validarPronosticos(selecciones,pronosticoA,pronosticoB);
        if(referencia==null) throw new IllegalArgumentException("Referencia obligatoria.");
        ResultadoApuesta r=apuestaDAO.realizarApuesta(idUsuario,construirSeleccionesJson(selecciones),monto,
                referencia,ip,pronosticoA,pronosticoB);
        if(r==null) throw new SQLException("Resultado de apuesta ausente.");
        if(r.isSolicitudIdempotente() && r.getCantidadSelecciones()==0) {
            // SQL comprobo la identidad exacta de las selecciones y el pronostico.
            r.setCantidadSelecciones(selecciones.size());
        }
        if(r.getCantidadSelecciones()!=selecciones.size()
                || !r.getTipoBoleto().equals(selecciones.size()==1?"SIMPLE":"COMPUESTO"))
            throw new SQLException("Resultado de apuesta inconsistente.");
        return r;
    }

    private void validarPronosticos(List<Integer> selecciones,Integer a,Integer b) {
        if((a==null)!=(b==null) || (a!=null && (a<0 || b<0 || selecciones.size()!=1)))
            throw new IllegalArgumentException("Pronosticos invalidos.");
        // La modalidad pertenece a la seleccion en SQL, nunca a una etiqueta enviada por el cliente.
    }

    public Boleto obtenerBoletoPorId(
            int idUsuarioSolicitante,
            int idBoleto)
            throws SQLException {

        validarUsuario(
                idUsuarioSolicitante
        );

        if (idBoleto <= 0) {

            throw new IllegalArgumentException(
                    "El boleto seleccionado no es válido."
            );
        }

        return apuestaDAO.obtenerBoleto(
                idUsuarioSolicitante,
                idBoleto,
                null
        );
    }

    public Boleto obtenerBoletoPorCodigo(
            int idUsuarioSolicitante,
            String codigoBoleto)
            throws SQLException {

        validarUsuario(
                idUsuarioSolicitante
        );

        if (codigoBoleto == null
                || codigoBoleto.trim().isEmpty()) {

            throw new IllegalArgumentException(
                    "El código del boleto es obligatorio."
            );
        }

        String codigo =
                codigoBoleto.trim();

        if (codigo.length() > 40) {

            throw new IllegalArgumentException(
                    "El código del boleto no puede superar "
                    + "los 40 caracteres."
            );
        }

        return apuestaDAO.obtenerBoleto(
                idUsuarioSolicitante,
                null,
                codigo
        );
    }

    private void validarUsuario(
            int idUsuario) {

        if (idUsuario <= 0) {

            throw new IllegalArgumentException(
                    "El usuario no es válido."
            );
        }
    }

    private void validarSelecciones(
            List<Integer> idSelecciones) {

        if (idSelecciones == null
                || idSelecciones.isEmpty()) {

            throw new IllegalArgumentException(
                    "Debe seleccionar al menos "
                    + "una opción para apostar."
            );
        }

        for (Integer idSeleccion
                : idSelecciones) {

            if (idSeleccion == null
                    || idSeleccion <= 0) {

                throw new IllegalArgumentException(
                        "Existe una selección no válida."
                );
            }
        }

        long cantidadUnicas =
                idSelecciones
                        .stream()
                        .distinct()
                        .count();

        if (cantidadUnicas
                != idSelecciones.size()) {

            throw new IllegalArgumentException(
                    "No se puede repetir una selección "
                    + "en el mismo boleto."
            );
        }
    }

    private void validarMonto(BigDecimal monto) {
        if(monto==null || monto.signum()<=0 || monto.compareTo(new BigDecimal("9999999999.99"))>0
                || monto.stripTrailingZeros().scale()>2)
            throw new IllegalArgumentException("Monto fuera del contrato DECIMAL(12,2).");
    }

    private String construirSeleccionesJson(
            List<Integer> idSelecciones) {

        StringBuilder json =
                new StringBuilder("[");

        for (int i = 0;
             i < idSelecciones.size();
             i++) {

            if (i > 0) {
                json.append(",");
            }

            json.append(
                    idSelecciones.get(i)
            );
        }

        json.append("]");

        return json.toString();
    }

}
