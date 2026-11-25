package com.manager.money_manager.repository;

import com.manager.money_manager.model.Transaction;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Path;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.jpa.domain.Specification;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@SuppressWarnings({"unchecked", "rawtypes"})
class TransactionSpecificationsTest {

    private final CriteriaBuilder cb = mock(CriteriaBuilder.class);
    private final CriteriaQuery<?> query = mock(CriteriaQuery.class);
    private final Root<Transaction> root = mock(Root.class);
    private final Path notePath = mock(Path.class);
    private final Path categoryPath = mock(Path.class);
    private final Path categoryNamePath = mock(Path.class);
    private final Expression<String> lowerNote = mock(Expression.class);
    private final Expression<String> lowerCategory = mock(Expression.class);
    private final Predicate notePredicate = mock(Predicate.class);
    private final Predicate categoryPredicate = mock(Predicate.class);
    private final Predicate combined = mock(Predicate.class);

    private Predicate apply(String search) {
        when(root.get("note")).thenReturn(notePath);
        when(root.get("category")).thenReturn(categoryPath);
        when(categoryPath.get("name")).thenReturn(categoryNamePath);
        when(cb.lower(notePath)).thenReturn(lowerNote);
        when(cb.lower(categoryNamePath)).thenReturn(lowerCategory);
        when(cb.like(eq(lowerNote), anyString(), eq('\\'))).thenReturn(notePredicate);
        when(cb.like(eq(lowerCategory), anyString(), eq('\\'))).thenReturn(categoryPredicate);
        when(cb.or(notePredicate, categoryPredicate)).thenReturn(combined);
        return TransactionSpecifications.noteContains(search).toPredicate(root, query, cb);
    }

    @Test
    void noteContains_escapesLikeWildcardsSoInputMatchesLiterally() {
        assertSame(combined, apply("50%_a\\b"));

        ArgumentCaptor<String> pattern = ArgumentCaptor.forClass(String.class);
        verify(cb).like(eq(lowerNote), pattern.capture(), eq('\\'));
        assertEquals("%50\\%\\_a\\\\b%", pattern.getValue());
    }

    @Test
    void noteContains_searchesCategoryNameAsWellAsNote() {
        apply("Food");

        verify(cb).like(eq(lowerNote), eq("%food%"), eq('\\'));
        verify(cb).like(eq(lowerCategory), eq("%food%"), eq('\\'));
    }

    @Test
    void noteContains_blankSearchAddsNoFilter() {
        Specification<Transaction> spec = TransactionSpecifications.noteContains("   ");

        assertNull(spec.toPredicate(root, query, cb));
        verifyNoInteractions(cb);
    }
}
