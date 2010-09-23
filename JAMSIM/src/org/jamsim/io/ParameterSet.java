package org.jamsim.io;

import java.awt.Component;

import javax.swing.table.TableModel;

/**
 * A set of parameters. The parameters are represented by a {@link TableModel}.
 * 
 * @author Oliver Mannion
 * @version $Revision$
 */
public interface ParameterSet {

	/**
	 * Reset the parameters to their default values.
	 * 
     * @param parentComponent determines the <code>Frame</code> in
     *		which the dialog is displayed; if <code>null</code>,
     *		or if the <code>parentComponent</code> has no
     *		<code>Frame</code>, a default <code>Frame</code> is used
	 */
	void resetDefaults(Component parentComponent);

	/**
	 * Process a change to the parameter set (ie: the underlying
	 * {@link TableModel}). External methods should call this after making any
	 * changes to the underlying {@link TableModel}.
	 * 
     * @param parentComponent determines the <code>Frame</code> in
     *		which the dialog is displayed; if <code>null</code>,
     *		or if the <code>parentComponent</code> has no
     *		<code>Frame</code>, a default <code>Frame</code> is used
	 */
	void update(Component parentComponent);

	/**
	 * Name of this {@link ParameterSet}.
	 * 
	 * @return name
	 */
	String getName();

	/**
	 * {@link TableModel} of parameters represented by the {@link ParameterSet}.
	 * 
	 * @return table model
	 */
	TableModel getTableModel();
}
