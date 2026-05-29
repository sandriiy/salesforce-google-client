import LightningDatatable from 'lightning/datatable';
import fileTitleTemplate from './fileTitle.html';

export default class GoogleCloudFileExplorerDataTable extends LightningDatatable {
	static customTypes = {
		fileTitle: {
			template: fileTitleTemplate,
			standardCellLayout: true,
			typeAttributes: ['label', 'title', 'rowId']
		}
	};
}