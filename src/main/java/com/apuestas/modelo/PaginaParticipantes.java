package com.apuestas.modelo;

import java.util.*;

/** Respuesta paginada; reutiliza Participante sin modificar su representacion. */
public final class PaginaParticipantes {
    public final boolean ok=true;
    public final int pagina,tamanoPagina;
    public final long total;
    public final List<Participante> participantes;
    public PaginaParticipantes(int pagina,int tamanoPagina,long total,List<Participante> participantes) {
        this.pagina=pagina;this.tamanoPagina=tamanoPagina;this.total=total;
        this.participantes=Collections.unmodifiableList(new ArrayList<>(participantes));
    }
}
