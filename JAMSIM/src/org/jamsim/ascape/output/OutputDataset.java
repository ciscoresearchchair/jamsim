package org.jamsim.ascape.output;

import java.io.IOException;
import java.util.Collection;
import java.util.TooManyListenersException;

import javax.swing.JTable;
import javax.swing.table.TableCellRenderer;
import javax.swing.table.TableModel;

import net.casper.data.model.CDataCacheContainer;
import net.casper.data.model.CDataGridException;
import net.casper.ext.CasperUtil;
import net.casper.ext.swing.CDatasetTableModel;

import org.ascape.model.event.DefaultScapeListener;
import org.ascape.model.event.ScapeEvent;
import org.ascape.runtime.swing.navigator.NodesByRunFolder;
import org.ascape.util.data.StatCollector;
import org.jamsim.ascape.MicroSimScape;
import org.jamsim.ascape.r.ScapeRInterface;
import org.jamsim.r.RDataFrame;
import org.jamsim.r.RInterfaceException;
import org.jamsim.r.UnsupportedTypeException;
import org.omancode.io.FileUtil;
import org.omancode.swing.DoubleCellRenderer;
import org.omancode.util.DateUtil;
import org.rosuda.REngine.REXP;
import org.rosuda.REngine.REXPMismatchException;

/**
 * Display output from a {@link OutputDatasetProvider}. When the scape stops
 * after each run, adds an output data table node in the Navigator that displays
 * the {@link OutputDatasetProvider} results in a table, and optionally outputs
 * the results to a file. When the simulation finishes running, creates a multi
 * run node if the {@link OutputDatasetProvider} is a
 * {@link MultiRunOutputDatasetProvider}.
 * 
 * @author Oliver Mannion
 * @version $Revision$
 */
public class OutputDataset extends DefaultScapeListener {
	private static final long serialVersionUID = -5105471052036807288L;

	private final NodesByRunFolder outputTablesNode;

	private final OutputDatasetProvider outDataset;

	private final String outputDirectory;

	private int runNumber = 0;

	private boolean scapeClosed = false;

	private ScapeRInterface scapeR;
	
	private MicroSimScape<?> msscape;

	/**
	 * Master constructor.
	 * 
	 * @param outputTablesNode
	 *            navigator output tables tree node
	 * @param outDataset
	 *            {@link OutputDatasetProvider}
	 * @param outputDirectory
	 *            destination directory for results output file
	 */
	public OutputDataset(NodesByRunFolder outputTablesNode,
			OutputDatasetProvider outDataset, String outputDirectory) {
		super(outDataset.getName());
		this.outDataset = outDataset;
		this.outputTablesNode = outputTablesNode;
		this.outputDirectory = FileUtil.addTrailingSlash(outputDirectory);
	}

	/**
	 * Add the view to the scape, registering it as a listener, and ensuring
	 * that it hasn't been added to any other scapes.
	 * 
	 * @param scapeEvent
	 *            the event for this scape to make this view the observer of
	 * @throws TooManyListenersException
	 *             the too many listeners exception
	 * @exception TooManyListenersException
	 *                on attempt to add a scape when one is already added
	 */
	@Override
	public void scapeAdded(ScapeEvent scapeEvent)
			throws TooManyListenersException {
		super.scapeAdded(scapeEvent);

		if (!(scape instanceof MicroSimScape<?>)) {
			throw new IllegalArgumentException(this.getClass()
					.getSimpleName()
					+ " must be added to an instance of "
					+ MicroSimScape.class.getSimpleName());
		}

		msscape = (MicroSimScape<?>) scape;
		scapeR = msscape.getScapeRInterface();

		if (outDataset instanceof StatCollectorProvider) {
			addStatCollectors((StatCollectorProvider) outDataset);
		}

		if (outDataset instanceof ChartProvider) {
			msscape.addChart((ChartProvider) outDataset);
		}

	}

	/**
	 * Add {@link StatCollector}s on the scape to record data during the
	 * simulation.
	 * 
	 * @param stats
	 *            collection of {@link StatCollector}s to add to the scape.
	 */
	private void addStatCollectors(StatCollectorProvider statsProvider) {

		Collection<? extends StatCollector> stats =
				statsProvider.getStatCollectors();

		for (StatCollector sc : stats) {
			scape.addStatCollector(sc);
		}
	}

	/**
	 * Perform operations required when the simulation has stopped. Here we
	 * write create an output node on the Navigator tree and optionally output
	 * the results to a file if {@link MicroSimScape#isResultsToFile()} is true.
	 * 
	 * @param scapeEvent
	 *            not used
	 */
	@Override
	public void scapeStopped(ScapeEvent scapeEvent) {
		runNumber++;

		// create the output node on the AWT event thread
		/*
		 * Runnable doWorkRunnable = new Runnable() { public void run() {
		 * createOutputNode(); } }; SwingUtilities.invokeLater(doWorkRunnable);
		 */

		try {
			String runName = name + " (Run " + runNumber + ")";
			CDataCacheContainer results =
					outDataset.getOutputDataset(runNumber);

			if (results != null) {
				createNavigatorOutputNode(runNumber, runName, results);

				if (msscape.isResultsToFile()) {
					writeCSV(runName, results);
				}
			} else {
				// silently ignore null results
			}

		} catch (IOException e) {
			throw new RuntimeException(e);
		} catch (CDataGridException e) {
			throw new RuntimeException(e);
		}

	}

	private void writeCSV(CDataCacheContainer container) throws IOException {
		writeCSV(container.getCacheName(), container);
	}

	private void writeCSV(String runName, CDataCacheContainer container)
			throws IOException {

		// strip runName of any illegal characters
		String cleanedRunName = FileUtil.stripInvalidFileNameChars(runName);
		String fileName =
				outputDirectory + DateUtil.nowToSortableUniqueDateString()
						+ " " + cleanedRunName + ".csv";

		CasperUtil.writeToCSV(fileName, container);
	}

	/**
	 * Create the multi-run dataset node when the simulation has finished, if
	 * the {@link OutputDatasetProvider} is a
	 * {@link MultiRunOutputDatasetProvider}.
	 */
	@Override
	public void scapeClosing(ScapeEvent scapeEvent) {

		// scapeClosing gets called twice when the scape closes
		// so we need a flag to make sure
		// it doesn't get called twice
		if (runNumber > 0 && !scapeClosed
				&& outDataset instanceof MultiRunOutputDatasetProvider) {
			createMultiRunNode();
		}

	}

	/**
	 * Create a multi-run node. Optionally output the results to a file if
	 * {@link MicroSimScape#isResultsToFile()} is true.
	 */
	private void createMultiRunNode() {
		// create multi-run node
		try {
			CDataCacheContainer allRuns =
					((MultiRunOutputDatasetProvider) outDataset)
							.getMultiRunDataset();

			scapeClosed = true;

			String dfName = outDataset.getShortName();
			try {

				scapeR.assignDataFrame(dfName, allRuns);
				scapeR.printlnToConsole("Created dataframe " + dfName + "("
						+ outDataset.getName() + ")");

			} catch (RInterfaceException e) {
				throw new RuntimeException("Couldn't create dataframe "
						+ dfName + ": " + e.getMessage(), e);
			}

			String rcmd = "meanOfRuns(" + dfName + ")";
			try {
				REXP rexp = scapeR.eval(rcmd);
				RDataFrame df = new RDataFrame(allRuns.getCacheName(), rexp);

				CDataCacheContainer meanOfRuns = new CDataCacheContainer(df);

				createNavigatorOutputNode(NodesByRunFolder.ALLRUNS,
						meanOfRuns.getCacheName(), meanOfRuns);

				if (msscape.isResultsToFile()) {
					writeCSV(meanOfRuns);
				}

			} catch (RInterfaceException e) {
				throw new RuntimeException(rcmd + ": " + e.getMessage(), e);
			} catch (REXPMismatchException e) {
				throw new RuntimeException(e);
			} catch (UnsupportedTypeException e) {
				throw new RuntimeException(e);
			} catch (IOException e) {
				throw new RuntimeException(e);
			}

		} catch (CDataGridException e) {
			throw new RuntimeException(e);
		}

	}

	/**
	 * Create a node on the Navigator tree that represents this dataset.
	 * 
	 */
	private void createNavigatorOutputNode(int runNumber, String nodeName,
			CDataCacheContainer container) {
		TableModel tmodel;
		try {
			tmodel = new CDatasetTableModel(container, true);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}

		createNavigatorOutputNode(runNumber, nodeName, tmodel);
	}

	/**
	 * Create a node on the Navigator tree that represents this table model.
	 * 
	 */
	private void createNavigatorOutputNode(int runNumber, String nodeName,
			TableModel tmodel) {

		TableCellRenderer dblRenderer = new DoubleCellRenderer();
		JTable table = new JTable(tmodel);
		table.setName(nodeName);
		table.setDefaultRenderer(Double.class, dblRenderer);

		outputTablesNode.addChildTableNode(runNumber, table);

	}

}