public class GoogleFileSharingApplyResultDTO {
	public Id recordId;
	public Boolean wasCreated;

	public GoogleFileSharingApplyResultDTO(Id recordId, Boolean wasCreated) {
		this.recordId = recordId;
		this.wasCreated = wasCreated;
	}
}