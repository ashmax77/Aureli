package com.manager.money_manager.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.PAYLOAD_TOO_LARGE)
public class ExportLimitExceededException extends RuntimeException {
    public ExportLimitExceededException(int maxRows) {
        super("Export is limited to " + maxRows + " transactions. Narrow the date range or filters and try again.");
    }
}