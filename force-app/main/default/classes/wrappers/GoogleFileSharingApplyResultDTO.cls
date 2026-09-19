/**
 * What creating a share ended with. wasCreated is false when the share was already there, which is how a
 * caller avoids repeating the work that follows a real one.
 */
public class GoogleFileSharingApplyResultDTO {
	public Id recordId;
	public Boolean wasCreated;

	/**
	 * Holds the outcome of a share.
	 *
	 * @param recordId The share or link, new or existing.
	 * @param wasCreated True when this call created it.
	 */
	public GoogleFileSharingApplyResultDTO(Id recordId, Boolean wasCreated) {
		this.recordId = recordId;
		this.wasCreated = wasCreated;
	}
}